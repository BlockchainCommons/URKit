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
    public static func encode<T: CBOREncodable>(_ value: T, _ context: CBORContext) -> Data {
        return value.cborEncode(context)
    }

    /// Encodes an array as either a CBOR array type or a CBOR bytestring type, depending on `asByteString`.
    /// NOTE: when `asByteString` is true and T = UInt8, the array is interpreted in network byte order
    /// Arrays with values of all other types will have their bytes reversed if the system is little endian.
    public static func encode<T: CBOREncodable>(_ array: [T], asByteString: Bool = false, _ context: CBORContext) -> Data {
        if asByteString {
            switch context {
            case .binary:
                let length = array.count
                var res = length.cborEncode(context)
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
            case .diagnostic:
                fatalError("Unimplemented")
            }
        } else {
            return encodeArray(array, context)
        }
    }

    public static func encode<A: CBOREncodable, B: CBOREncodable>(_ dict: [A: B], _ context: CBORContext) -> Data {
        return encodeMap(dict, context)
    }

    // MARK: - major 0: unsigned integer

    public static func encodeUInt8(_ x: UInt8, _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            if (x < 24) { return Data([x]) }
            else { return Data([0x18, x]) }
        case .diagnostic:
            return String(x).utf8Data
        }
    }

    public static func encodeUInt16(_ x: UInt16, _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data([0x19] + rawBytes(of: x))
        case .diagnostic:
            return String(x).utf8Data
        }
    }

    public static func encodeUInt32(_ x: UInt32, _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data([0x1a] + rawBytes(of: x))
        case .diagnostic:
            return String(x).utf8Data
        }
    }

    public static func encodeUInt64(_ x: UInt64, _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data([0x1b] + rawBytes(of: x))
        case .diagnostic:
            return String(x).utf8Data
        }
    }

    internal static func encodeVarUInt(_ x: UInt64, _ context: CBORContext) -> Data {
        switch x {
        case let x where x <= UInt8.max: return CBOR.encodeUInt8(UInt8(x), context)
        case let x where x <= UInt16.max: return CBOR.encodeUInt16(UInt16(x), context)
        case let x where x <= UInt32.max: return CBOR.encodeUInt32(UInt32(x), context)
        default: return CBOR.encodeUInt64(x, context)
        }
    }

    // MARK: - major 1: negative integer

    public static func encodeNegativeInt(_ x: Int64, _ context: CBORContext) -> Data {
        assert(x < 0)
        switch context {
        case .binary:
            var res = encodeVarUInt(~UInt64(bitPattern: x), context)
            res[0] = res[0] | 0b001_00000
            return res
        case .diagnostic:
            return String(x).utf8Data
        }
    }

    // MARK: - major 2: bytestring

    public static func encodeByteString(_ bs: [UInt8], _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            var res = bs.count.cborEncode(context)
            res[0] = res[0] | 0b010_00000
            res.append(contentsOf: bs)
            return res
        case .diagnostic:
            return Data(bs).hex.flanked("h'", "'").utf8Data
        }
    }

    public static func encodeData(_ data: Data, _ context: CBORContext) -> Data {
        return encodeByteString(data.bytes, context)
    }

    // MARK: - major 3: UTF8 string

    public static func encodeString(_ str: String, _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            let utf8array = Array(str.utf8)
            var res = utf8array.count.cborEncode(context)
            res[0] = res[0] | 0b011_00000
            res.append(contentsOf: utf8array)
            return res
        case .diagnostic:
            return str.flanked("\"").utf8Data
        }
    }

    // MARK: - major 4: array of data items

    public static func encodeArray<T: CBOREncodable>(_ arr: [T], _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            var res = arr.count.cborEncode(context)
            res[0] = res[0] | 0b100_00000
            res.append(contentsOf: arr.flatMap{ return $0.cborEncode(context) })
            return res
        case .diagnostic:
            return arr.map({ $0.cborEncode(context).utf8! }).joined(separator: ", ").flanked("[", "]").utf8Data
        }
    }

    // MARK: - major 5: a map of pairs of data items

    public static func encodeMap<A: CBOREncodable, B: CBOREncodable>(_ map: [A: B], _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            var res = Data()
            res.reserveCapacity(1 + map.count * (MemoryLayout<A>.size + MemoryLayout<B>.size + 2))
            res = map.count.cborEncode(context)
            res[0] = res[0] | 0b101_00000
            for (k, v) in map {
                res.append(contentsOf: k.cborEncode(context))
                res.append(contentsOf: v.cborEncode(context))
            }
            return res
        case .diagnostic:
            return map.map { (k, v) in
                [k.cborEncode(context).utf8!, v.cborEncode(context).utf8!].joined(separator: ": ")
            }
            .joined(separator: ", ")
            .flanked("{", "}")
            .utf8Data
        }
    }

    public static func encodeOrderedMap(_ map: [OrderedMapEntry], _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            var res = Data()
            res = map.count.cborEncode(context)
            res[0] = res[0] | 0b101_00000
            for entry in map {
                res.append(contentsOf: entry.key.cborEncode(context))
                res.append(contentsOf: entry.value.cborEncode(context))
            }
            return res
        case .diagnostic:
            return map.map { entry in
                [
                    entry.key.cborEncode(context).utf8!,
                    entry.value.cborEncode(context).utf8!
                ]
                    .joined(separator: ": ")
            }
            .joined(separator: ", ")
            .flanked("{", "}")
            .utf8Data
        }
    }

    public static func encodeMap<A: CBOREncodable>(_ map: [A: Any?], _ context: CBORContext) throws -> Data {
        switch context {
        case .binary:
            var res = Data()
            res = map.count.cborEncode(context)
            res[0] = res[0] | 0b101_00000
            try CBOR.encodeMap(map, into: &res)
            return res
        case .diagnostic:
            fatalError("Unimplemented")
        }
    }

    // MARK: - major 6: tagged values

    public static func encodeTagged<T: CBOREncodable>(tag: Tag, value: T, _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            var res = encodeVarUInt(tag.rawValue, context)
            res[0] = res[0] | 0b110_00000
            res.append(contentsOf: value.cborEncode(context))
            return res
        case .diagnostic:
            return (String(tag.rawValue) + value.cborEncode(context).utf8!.flanked("(", ")")).utf8Data
        }
    }

    // MARK: - major 7: floats, simple values, the 'break' stop code

    public static func encodeSimpleValue(_ x: UInt8, _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            if x < 24 {
                return Data([0b111_00000 | x])
            } else {
                return Data([0xf8, x])
            }
        case .diagnostic:
            return String(x).utf8Data
        }
    }

    public static func encodeNull(_ context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data([0xf6])
        case .diagnostic:
            return "null".utf8Data
        }
    }

    public static func encodeUndefined(_ context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data([0xf7])
        case .diagnostic:
            return "undefined".utf8Data
        }
    }

    public static func encodeBreak(_ context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data([0xff])
        case .diagnostic:
            fatalError("Unimplemented")
        }
    }

    public static func encodeFloat(_ x: Float, _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data([0xfa] + rawBytes(of: x))
        case .diagnostic:
            return String(x).utf8Data
        }
    }

    public static func encodeDouble(_ x: Double, _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data([0xfb] + rawBytes(of: x))
        case .diagnostic:
            return String(x).utf8Data
        }
    }

    public static func encodeBool(_ x: Bool, _ context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data(x ? [0xf5] : [0xf4])
        case .diagnostic:
            return (x ? "true" : "false").utf8Data
        }
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
    public static func encodeArrayStreamStart(context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data([0x9f])
        case .diagnostic:
            fatalError("Unimplemented")
        }
    }

    public static func encodeMapStreamStart(context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data([0xbf])
        case .diagnostic:
            fatalError("Unimplemented")
        }
    }

    public static func encodeStringStreamStart(context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data([0x7f])
        case .diagnostic:
            fatalError("Unimplemented")
        }
    }

    public static func encodeByteStringStreamStart(context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data([0x5f])
        case .diagnostic:
            fatalError("Unimplemented")
        }
    }

    /// This is the same as a CBOR "break" value
    public static func encodeStreamEnd(context: CBORContext) -> Data {
        switch context {
        case .binary:
            return Data([0xff])
        case .diagnostic:
            fatalError("Unimplemented")
        }
    }

    // TODO: unify definite and indefinite code
    public static func encodeArrayChunk<T: CBOREncodable>(_ chunk: [T], context: CBORContext) -> Data {
        var res = Data()
        res.reserveCapacity(chunk.count * MemoryLayout<T>.size)
        res.append(contentsOf: chunk.flatMap{ return $0.cborEncode(context) })
        return res
    }

    public static func encodeMapChunk<A: CBOREncodable, B: CBOREncodable>(_ map: [A: B], context: CBORContext) -> Data {
        var res = Data()
        let count = map.count
        res.reserveCapacity(count * MemoryLayout<A>.size + count * MemoryLayout<B>.size)
        for (k, v) in map {
            res.append(contentsOf: k.cborEncode(context))
            res.append(contentsOf: v.cborEncode(context))
        }
        return res
    }

    public static func encodeDate(_ date: Date, _ context: CBORContext) -> Data {
        let timeInterval = date.timeIntervalSince1970
        let (integral, fractional) = modf(timeInterval)

        let seconds = Int64(integral)
        let nanoseconds = UInt32(fractional * Double(NSEC_PER_SEC))

        var res = Data()
        if seconds < 0 {
            res.append(contentsOf: CBOR.encodeNegativeInt(Int64(timeInterval), context))
        } else if seconds > UInt32.max {
            res.append(contentsOf: CBOR.encodeDouble(timeInterval, context))
        } else if nanoseconds > 0 {
            res.append(contentsOf: CBOR.encodeDouble(timeInterval, context))
        } else {
            res.append(contentsOf: CBOR.encode(Int(seconds), context))
        }

        switch context {
        case .binary:
            // Epoch timestamp tag is 1
            return Data([0b110_00001]) + res
        case .diagnostic:
            return res.utf8!.flanked("1(", ")").utf8Data
        }
    }

    public static func encodeAny(_ any: Any?, _ context: CBORContext) throws -> Data {
        switch any {
        case is Int:
            return (any as! Int).cborEncode(context)
        case is UInt:
            return (any as! UInt).cborEncode(context)
        case is UInt8:
            return (any as! UInt8).cborEncode(context)
        case is UInt16:
            return (any as! UInt16).cborEncode(context)
        case is UInt32:
            return (any as! UInt32).cborEncode(context)
        case is UInt64:
            return (any as! UInt64).cborEncode(context)
        case is String:
            return (any as! String).cborEncode(context)
        case is Float:
            return (any as! Float).cborEncode(context)
        case is Double:
            return (any as! Double).cborEncode(context)
        case is Bool:
            return (any as! Bool).cborEncode(context)
        case is [UInt8]:
            return CBOR.encodeByteString(any as! [UInt8], context)
        case is Data:
            return CBOR.encodeData(any as! Data, context)
        case is Date:
            return CBOR.encodeDate(any as! Date, context)
        case is NSNull:
            return CBOR.encodeNull(context)
        case is [Any]:
            switch context {
            case .binary:
                let anyArr = any as! [Any]
                var res = anyArr.count.cborEncode(context)
                res[0] = res[0] | 0b100_00000
                let encodedInners = try anyArr.reduce(into: []) { acc, next in
                    acc.append(contentsOf: try encodeAny(next, context))
                }
                res.append(contentsOf: encodedInners)
                return res
            case .diagnostic:
                fatalError("Unimplemented")
            }
        case is [String: Any]:
            switch context {
            case .binary:
                let anyMap = any as! [String: Any]
                var res = anyMap.count.cborEncode(context)
                res[0] = res[0] | 0b101_00000
                try CBOR.encodeMap(anyMap, into: &res)
                return res
            case .diagnostic:
                fatalError("Unimplemented")
            }
        case is Void:
            return CBOR.encodeUndefined(context)
        case nil:
            return CBOR.encodeNull(context)
        default:
            throw CBOREncoderError.invalidType
        }
    }

    private static func encodeMap<A: CBOREncodable>(_ map: [A: Any?], into res: inout Data) throws {
        let sortedKeysWithEncodedKeys = map.keys.map {
            (encoded: $0.cborEncode(.binary), key: $0)
        }.sorted(by: {
            $0.encoded.lexicographicallyPrecedes($1.encoded)
        })

        try sortedKeysWithEncodedKeys.forEach { keyTuple in
            res.append(contentsOf: keyTuple.encoded)
            let encodedVal = try encodeAny(map[keyTuple.key]!, .binary)
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
