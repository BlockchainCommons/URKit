// From: https://github.com/myfreeweb/SwiftCBOR
// License: Public Domain

import Foundation

public enum CBORDecodingError : LocalizedError {
    case unfinishedSequence
    case wrongTypeInsideSequence
    case tooLongSequence
    case incorrectUTF8String
    case typeMismatch
    case valueOutOfRange
    
    public var errorDescription: String? {
        switch self {
        case .unfinishedSequence:
            return "CBOR: Unfinished sequence."
        case .wrongTypeInsideSequence:
            return "CBOR: Wrong type inside."
        case .tooLongSequence:
            return "CBOR: Sequence too long."
        case .incorrectUTF8String:
            return "CBOR: Incorrect UTF8 string."
        case .typeMismatch:
            return "CBOR: Type mismatch."
        case .valueOutOfRange:
            return "CBOR: Value out of range."
        }
    }
}

extension CBOR {
    static func decode(_ input: Data, orderedKeys: Bool = false) throws -> CBOR? {
        return try CBORDecoder(input: input.bytes, orderedKeys: orderedKeys).decodeItem()
    }

    static func decode(_ input: [UInt8], orderedKeys: Bool = false) throws -> CBOR? {
        return try CBORDecoder(input: input, orderedKeys: orderedKeys).decodeItem()
    }
}

extension CBOR {
    public init(_ input: Data, orderedKeys: Bool = false) throws {
        guard let c = try Self.decode(input, orderedKeys: orderedKeys) else {
            throw CBORDecodingError.unfinishedSequence
        }
        self = c
    }

    public init(_ input: [UInt8], orderedKeys: Bool = false) throws {
        guard let c = try Self.decode(input, orderedKeys: orderedKeys) else {
            throw CBORDecodingError.unfinishedSequence
        }
        self = c
    }
}

public class CBORDecoder {
    private var istream : CBORInputStream
    private let orderedKeys: Bool

    public init(stream: CBORInputStream, orderedKeys: Bool = false) {
        istream = stream
        self.orderedKeys = orderedKeys
    }

    public init(input: ArraySlice<UInt8>, orderedKeys: Bool = false) {
        istream = ArraySliceUInt8(slice: input)
        self.orderedKeys = orderedKeys
    }

    public init(input: [UInt8], orderedKeys: Bool = false) {
        istream = ArrayUInt8(array: input)
        self.orderedKeys = orderedKeys
    }

    func readBinaryNumber<T>(_ type: T.Type) throws -> T {
        Array(try self.istream.popBytes(MemoryLayout<T>.size).reversed()).withUnsafeBytes { ptr in
            return ptr.load(as: T.self)
        }
    }

    func readVarUInt(_ v: UInt8, base: UInt8) throws -> UInt64 {
        guard v > base + 0x17 else { return UInt64(v - base) }

        switch VarUIntSize(rawValue: v) {
        case .uint8: return UInt64(try readBinaryNumber(UInt8.self))
        case .uint16: return UInt64(try readBinaryNumber(UInt16.self))
        case .uint32: return UInt64(try readBinaryNumber(UInt32.self))
        case .uint64: return UInt64(try readBinaryNumber(UInt64.self))
        }
    }

    func readLength(_ v: UInt8, base: UInt8) throws -> Int {
        let n = try readVarUInt(v, base: base)

        guard n <= Int.max else {
            throw CBORDecodingError.tooLongSequence
        }

        return Int(n)
    }

    private func readN(_ n: Int) throws -> [CBOR] {
        return try (0..<n).map { _ in
            guard let r = try decodeItem() else { throw CBORDecodingError.unfinishedSequence }
            return r
        }
    }

    func readUntilBreak() throws -> [CBOR] {
        var result: [CBOR] = []
        var cur = try decodeItem()
        while cur != CBOR.break {
            guard let curr = cur else { throw CBORDecodingError.unfinishedSequence }
            result.append(curr)
            cur = try decodeItem()
        }
        return result
    }

    private func readNPairs(_ n: Int) throws -> [CBOR : CBOR] {
        var result: [CBOR: CBOR] = [:]
        for _ in (0..<n) {
            guard let key  = try decodeItem() else { throw CBORDecodingError.unfinishedSequence }
            guard let val  = try decodeItem() else { throw CBORDecodingError.unfinishedSequence }
            result[key] = val
        }
        return result
    }

    private func readNOrderedPairs(_ n: Int) throws -> OrderedMap {
        var result: OrderedMap = [:]
        for _ in (0..<n) {
            guard let key  = try decodeItem() else { throw CBORDecodingError.unfinishedSequence }
            guard let val  = try decodeItem() else { throw CBORDecodingError.unfinishedSequence }
            result.append(key, val)
        }
        return result
    }

    func readPairsUntilBreak() throws -> [CBOR : CBOR] {
        var result: [CBOR: CBOR] = [:]
        var key = try decodeItem()
        if key == CBOR.break {
            return result
        }
        var val = try decodeItem()
        while key != CBOR.break {
            guard let okey = key else { throw CBORDecodingError.unfinishedSequence }
            guard let oval = val else { throw CBORDecodingError.unfinishedSequence }
            result[okey] = oval
            do { key = try decodeItem() } catch CBORDecodingError.unfinishedSequence { key = nil }
            guard (key != CBOR.break) else { break } // don't eat the val after the break!
            do { val = try decodeItem() } catch CBORDecodingError.unfinishedSequence { val = nil }
        }
        return result
    }

    func readOrderedPairsUntilBreak() throws -> OrderedMap {
        var result: OrderedMap = [:]
        var key = try decodeItem()
        if key == CBOR.break {
            return result
        }
        var val = try decodeItem()
        while key != CBOR.break {
            guard let okey = key else { throw CBORDecodingError.unfinishedSequence }
            guard let oval = val else { throw CBORDecodingError.unfinishedSequence }
            result.append(okey, oval)
            do { key = try decodeItem() } catch CBORDecodingError.unfinishedSequence { key = nil }
            guard (key != CBOR.break) else { break } // don't eat the val after the break!
            do { val = try decodeItem() } catch CBORDecodingError.unfinishedSequence { val = nil }
        }
        return result
    }

    public func decodeItem() throws -> CBOR? {
        let b = try istream.popByte()

        switch b {
        // positive integers
        case 0x00...0x1b:
            return CBOR.unsignedInt(try readVarUInt(b, base: 0x00))

        // negative integers
        case 0x20...0x3b:
            return CBOR.negativeInt(try readVarUInt(b, base: 0x20))

        // byte strings
        case 0x40...0x5b:
            let numBytes = try readLength(b, base: 0x40)
            return CBOR.data(Data(try istream.popBytes(numBytes)))
        case 0x5f:
            return CBOR.data(Data(try readUntilBreak().flatMap { x -> Data in
                guard case .data(let r) = x else { throw CBORDecodingError.wrongTypeInsideSequence }
                return r
            }))

        // utf-8 strings
        case 0x60...0x7b:
            let numBytes = try readLength(b, base: 0x60)
            return CBOR.utf8String(try CBORUtil.decodeUtf8(try istream.popBytes(numBytes)))
        case 0x7f:
            return CBOR.utf8String(try readUntilBreak().map { x -> String in
                guard case .utf8String(let r) = x else { throw CBORDecodingError.wrongTypeInsideSequence }
                return r
            }.joined(separator: ""))

        // arrays
        case 0x80...0x9b:
            let count = try readLength(b, base: 0x80)
            return CBOR.array(try readN(count))
        case 0x9f:
            return CBOR.array(try readUntilBreak())

        // pairs
        case 0xa0...0xbb:
            let count = try readLength(b, base: 0xa0)
            if orderedKeys {
                return CBOR.orderedMap(try readNOrderedPairs(count))
            } else {
                return CBOR.map(try readNPairs(count))
            }
        case 0xbf:
            if orderedKeys {
                return CBOR.orderedMap(try readOrderedPairsUntilBreak())
            } else {
                return CBOR.map(try readPairsUntilBreak())
            }

        // tagged values
        case 0xc0...0xdb:
            let tagRawValue = try readVarUInt(b, base: 0xc0)
            guard let item = try decodeItem() else { throw CBORDecodingError.unfinishedSequence }
            if tagRawValue == 1 {
                // Per https://datatracker.ietf.org/doc/html/rfc8949#section-3.4.2
                var seconds: TimeInterval
                switch item {
                case .double(let d):
                    seconds = TimeInterval(d)
                case .negativeInt(let n):
                    seconds = TimeInterval(n)
                case .float(let f):
                    seconds = TimeInterval(f)
                case .unsignedInt(let u):
                    seconds = TimeInterval(u)
                default:
                    throw CBORDecodingError.wrongTypeInsideSequence
                }
                let date = Date(timeIntervalSince1970: seconds)
                return CBOR.date(date)
            } else if tagRawValue == 100 {
                // Per https://datatracker.ietf.org/doc/html/rfc8943
                let days: Int?
                switch item {
                case .unsignedInt(let u):
                    days = Int(exactly: u)
                case .negativeInt(let n):
                    days = Int(exactly: n)
                default:
                    throw CBORDecodingError.wrongTypeInsideSequence
                }
                guard let days = days else {
                    throw CBORDecodingError.wrongTypeInsideSequence
                }
                let date = Calendar.current.date(byAdding: DateComponents(day: days), to: Date(timeIntervalSince1970: 0))!
                return CBOR.date(date)
            }
            return CBOR.tagged(CBOR.Tag.knownTag(for: tagRawValue), item)

        case 0xe0...0xf3: return CBOR.simple(b - 0xe0)
        case 0xf4: return CBOR.boolean(false)
        case 0xf5: return CBOR.boolean(true)
        case 0xf6: return CBOR.null
        case 0xf7: return CBOR.undefined
        case 0xf8: return CBOR.simple(try istream.popByte())

        case 0xf9:
            return CBOR.half(CBORUtil.readFloat16(x: try readBinaryNumber(UInt16.self)))
        case 0xfa:
            return CBOR.float(try readBinaryNumber(Float32.self))
        case 0xfb:
            return CBOR.double(try readBinaryNumber(Float64.self))

        case 0xff: return CBOR.break
        default: return nil
        }
    }

}

private enum VarUIntSize: UInt8 {
    case uint8 = 0
    case uint16 = 1
    case uint32 = 2
    case uint64 = 3

    init(rawValue: UInt8) {
        switch rawValue & 0b11 {
        case 0: self = .uint8
        case 1: self = .uint16
        case 2: self = .uint32
        case 3: self = .uint64
        default: fatalError() // mask only allows values from 0-3
        }
    }
}
