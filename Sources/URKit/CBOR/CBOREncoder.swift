// From: https://github.com/myfreeweb/SwiftCBOR
// License: Public Domain

import Foundation

let isBigEndian = Int(bigEndian: 42) == 42

/// Takes a value breaks it into bytes. assumes necessity to reverse for endianness if needed
/// This function has only been tested with UInt_s, Floats and Doubles
/// T must be a simple type. It cannot be a collection type.
func rawBytes<T>(of x: T) -> [UInt8] {
    var mutable = x // create mutable copy for `withUnsafeBytes`
    let bigEndianResult = withUnsafeBytes(of: &mutable) { Array($0) }
    return isBigEndian ? bigEndianResult : bigEndianResult.reversed()
}

/// Defines basic CBOR.encode API.
/// Defines more fine-grained functions of form CBOR.encode*(_ x)
/// for all CBOR types except Float16
extension CBOR {
    public static func encode<T: CBOREncodable>(_ value: T) -> Data {
        return value.cborEncode
    }

    /// Encodes an array as either a CBOR array type or a CBOR bytestring type, depending on `asByteString`.
    /// NOTE: when `asByteString` is true and T = UInt8, the array is interpreted in network byte order
    /// Arrays with values of all other types will have their bytes reversed if the system is little endian.
    public static func encode<T: CBOREncodable>(_ array: [T], asByteString: Bool = false) -> Data {
        if asByteString {
            let length = array.count
            var res = length.cborEncode
            res[0] = res[0] | 0b010_00000
            let itemSize = MemoryLayout<T>.size
            let bytelength = length * itemSize
            res.reserveCapacity(res.count + bytelength)

            let noReversalNeeded = isBigEndian || T.self == UInt8.self

            array.withUnsafeBytes { bufferPtr in
                guard let ptr = bufferPtr.baseAddress?.bindMemory(to: UInt8.self, capacity: bytelength) else {
                    fatalError("Invalid pointer")
                }
                var j = 0
                for i in 0..<bytelength {
                    j = noReversalNeeded ? i : bytelength - 1 - i
                    res.append((ptr + j).pointee)
                }
            }
            return res
        } else {
            return encodeArray(array)
        }
    }

    public static func encode<A: CBOREncodable, B: CBOREncodable>(_ dict: [A: B]) -> Data {
        return encodeMap(dict)
    }

    // MARK: - major 0: unsigned integer

    public static func encodeUInt8(_ x: UInt8) -> Data {
        if (x < 24) { return Data([x]) }
        else { return Data([0x18, x]) }
    }

    public static func encodeUInt16(_ x: UInt16) -> Data {
        return Data([0x19] + rawBytes(of: x))
    }

    public static func encodeUInt32(_ x: UInt32) -> Data {
        return Data([0x1a] + rawBytes(of: x))
    }

    public static func encodeUInt64(_ x: UInt64) -> Data {
        return Data([0x1b] + rawBytes(of: x))
    }

    internal static func encodeVarUInt(_ x: UInt64) -> Data {
        switch x {
        case let x where x <= UInt8.max: return CBOR.encodeUInt8(UInt8(x))
        case let x where x <= UInt16.max: return CBOR.encodeUInt16(UInt16(x))
        case let x where x <= UInt32.max: return CBOR.encodeUInt32(UInt32(x))
        default: return CBOR.encodeUInt64(x)
        }
    }

    // MARK: - major 1: negative integer

    public static func encodeNegativeInt(_ x: Int64) -> Data {
        assert(x < 0)
        var res = encodeVarUInt(~UInt64(bitPattern: x))
        res[0] = res[0] | 0b001_00000
        return res
    }

    // MARK: - major 2: bytestring

    public static func encodeByteString(_ bs: [UInt8]) -> Data {
        var res = byteStringHeader(count: bs.count)
        res.append(contentsOf: bs)
        return res
    }
    
    static func byteStringHeader(count: Int) -> Data {
        var res = count.cborEncode
        res[0] = res[0] | 0b010_00000
        return res
    }

    public static func encodeData(_ data: Data) -> Data {
        return encodeByteString(data.bytes)
    }

    // MARK: - major 3: UTF8 string

    static func stringHeader(str: String) -> Data {
        let utf8array = Array(str.utf8)
        var res = utf8array.count.cborEncode
        res[0] = res[0] | 0b011_00000
        return res
    }
    
    public static func encodeString(_ str: String) -> Data {
        var res = stringHeader(str: str)
        res.append(contentsOf: str.utf8Data)
        return res
    }

    // MARK: - major 4: array of data items

    public static func arrayHeader(count: Int) -> Data {
        var res = count.cborEncode
        res[0] = res[0] | 0b100_00000
        return res
    }
    
    public static func encodeArray<T: CBOREncodable>(_ arr: [T]) -> Data {
        var res = arrayHeader(count: arr.count)
        res.append(contentsOf: arr.flatMap{ return $0.cborEncode })
        return res
    }

    // MARK: - major 5: a map of pairs of data items

    public static func mapHeader(count: Int) -> Data {
        var res = Data()
        res = count.cborEncode
        res[0] = res[0] | 0b101_00000
        return res
    }
    
    public static func encodeMap<A: CBOREncodable, B: CBOREncodable>(_ map: [A: B]) -> Data {
        var res = mapHeader(count: map.count)
        res.reserveCapacity(1 + map.count * (MemoryLayout<A>.size + MemoryLayout<B>.size + 2))
        for (k, v) in map {
            res.append(contentsOf: k.cborEncode)
            res.append(contentsOf: v.cborEncode)
        }
        return res
    }

    public static func encodeOrderedMap(_ map: OrderedMap) -> Data {
        var res = mapHeader(count: map.count)
        for entry in map.elements {
            res.append(contentsOf: entry.key.cborEncode)
            res.append(contentsOf: entry.value.cborEncode)
        }
        return res
    }

    public static func encodeMap<A: CBOREncodable>(_ map: [A: Any?]) throws -> Data {
        var res = Data()
        res = map.count.cborEncode
        res[0] = res[0] | 0b101_00000
        try CBOR.encodeMap(map, into: &res)
        return res
    }

    // MARK: - major 6: tagged values

    public static func tagHeader(tag: Tag) -> Data {
        var res = encodeVarUInt(tag.rawValue)
        res[0] = res[0] | 0b110_00000
        return res
    }
    
    public static func encodeTagged<T: CBOREncodable>(tag: Tag, value: T) -> Data {
        var res = tagHeader(tag: tag)
        res.append(contentsOf: value.cborEncode)
        return res
    }

    // MARK: - major 7: floats, simple values, the 'break' stop code

    public static func encodeSimpleValue(_ x: UInt8) -> Data {
        if x < 24 {
            return Data([0b111_00000 | x])
        } else {
            return Data([0xf8, x])
        }
    }

    public static func encodeNull() -> Data {
        return Data([0xf6])
    }

    public static func encodeUndefined() -> Data {
        return Data([0xf7])
    }

    public static func encodeBreak() -> Data {
        return Data([0xff])
    }

    public static func encodeFloat(_ x: Float) -> Data {
        return Data([0xfa] + rawBytes(of: x))
    }

    public static func encodeDouble(_ x: Double) -> Data {
        return Data([0xfb] + rawBytes(of: x))
    }

    public static func encodeBool(_ x: Bool) -> Data {
        return Data(x ? [0xf5] : [0xf4])
    }

    // MARK: - Indefinite length items

    /// Returns a CBOR value indicating the opening of an indefinite-length data item.
    /// The user is responsible for creating and sending subsequent valid CBOR.
    /// In particular, the user must end the stream with the CBOR.break byte, which
    /// can be returned with `encodeStreamEnd()`.
    ///
    /// The stream API is limited right now, but will get better when Swift allows
    /// one to generically constrain the elements of generic Iterators, in which case
    /// streaming implementation is trivial
    public static func encodeArrayStreamStart() -> Data {
        return Data([0x9f])
    }

    public static func encodeMapStreamStart() -> Data {
        return Data([0xbf])
    }

    public static func encodeStringStreamStart() -> Data {
        return Data([0x7f])
    }

    public static func encodeByteStringStreamStart() -> Data {
        return Data([0x5f])
    }

    /// This is the same as a CBOR "break" value
    public static func encodeStreamEnd() -> Data {
        return Data([0xff])
    }

    // TODO: unify definite and indefinite code
    public static func encodeArrayChunk<T: CBOREncodable>(_ chunk: [T]) -> Data {
        var res = Data()
        res.reserveCapacity(chunk.count * MemoryLayout<T>.size)
        res.append(contentsOf: chunk.flatMap{ return $0.cborEncode })
        return res
    }

    public static func encodeMapChunk<A: CBOREncodable, B: CBOREncodable>(_ map: [A: B]) -> Data {
        var res = Data()
        let count = map.count
        res.reserveCapacity(count * MemoryLayout<A>.size + count * MemoryLayout<B>.size)
        for (k, v) in map {
            res.append(contentsOf: k.cborEncode)
            res.append(contentsOf: v.cborEncode)
        }
        return res
    }
    
    public static func dateHeader() -> Data {
        Data([0b110_00001])
    }

    public static func encodeDate(_ date: Date) -> Data {
        let timeInterval = date.timeIntervalSince1970
        let (integral, fractional) = modf(timeInterval)

        let seconds = Int64(integral)
        let nanoseconds = UInt32(fractional * Double(NSEC_PER_SEC))

        var res = Data()
        if seconds < 0 {
            res.append(contentsOf: CBOR.encodeNegativeInt(Int64(timeInterval)))
        } else if seconds > UInt32.max {
            res.append(contentsOf: CBOR.encodeDouble(timeInterval))
        } else if nanoseconds > 0 {
            res.append(contentsOf: CBOR.encodeDouble(timeInterval))
        } else {
            res.append(contentsOf: CBOR.encode(Int(seconds)))
        }

        // Epoch timestamp tag is 1
        return dateHeader() + res
    }

    public static func encodeAny(_ any: Any?) throws -> Data {
        switch any {
        case is Int:
            return (any as! Int).cborEncode
        case is UInt:
            return (any as! UInt).cborEncode
        case is UInt8:
            return (any as! UInt8).cborEncode
        case is UInt16:
            return (any as! UInt16).cborEncode
        case is UInt32:
            return (any as! UInt32).cborEncode
        case is UInt64:
            return (any as! UInt64).cborEncode
        case is String:
            return (any as! String).cborEncode
        case is Float:
            return (any as! Float).cborEncode
        case is Double:
            return (any as! Double).cborEncode
        case is Bool:
            return (any as! Bool).cborEncode
        case is [UInt8]:
            return CBOR.encodeByteString(any as! [UInt8])
        case is Data:
            return CBOR.encodeData(any as! Data)
        case is Date:
            return CBOR.encodeDate(any as! Date)
        case is NSNull:
            return CBOR.encodeNull()
        case is [Any]:
            let anyArr = any as! [Any]
            var res = anyArr.count.cborEncode
            res[0] = res[0] | 0b100_00000
            let encodedInners = try anyArr.reduce(into: []) { acc, next in
                acc.append(contentsOf: try encodeAny(next))
            }
            res.append(contentsOf: encodedInners)
            return res
        case is [String: Any]:
            let anyMap = any as! [String: Any]
            var res = anyMap.count.cborEncode
            res[0] = res[0] | 0b101_00000
            try CBOR.encodeMap(anyMap, into: &res)
            return res
        case is Void:
            return CBOR.encodeUndefined()
        case nil:
            return CBOR.encodeNull()
        default:
            throw CBOREncoderError.invalidType
        }
    }

    private static func encodeMap<A: CBOREncodable>(_ map: [A: Any?], into res: inout Data) throws {
        let sortedKeysWithEncodedKeys = map.keys.map {
            (encoded: $0.cborEncode, key: $0)
        }.sorted(by: {
            $0.encoded.lexicographicallyPrecedes($1.encoded)
        })

        try sortedKeysWithEncodedKeys.forEach { keyTuple in
            res.append(contentsOf: keyTuple.encoded)
            let encodedVal = try encodeAny(map[keyTuple.key]!)
            res.append(contentsOf: encodedVal)
        }
    }
}

public enum CBOREncoderError: LocalizedError {
    case invalidType
    
    public var errorDescription: String? {
        switch self {
        case .invalidType:
            return "Invalid CBOR type."
        }
    }
}
