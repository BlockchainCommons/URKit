// From: https://github.com/myfreeweb/SwiftCBOR
// License: Public Domain

import Foundation
import WolfBase

public protocol CBOREncodable {
    var cborEncode: Data { get }
    var cbor: CBOR { get }
}

extension CBOREncodable {
    public var cborEncode: Data {
        cbor.cborEncode
    }
}

public protocol CBORDecodable {
    static func cborDecode(_ cbor: CBOR) throws -> Self
}

extension CBOR: CBOREncodable {
    /// Encodes a wrapped CBOR value. CBOR.half (Float16) is not supported and encodes as `undefined`.
    public var cborEncode: Data {
        switch self {
        case let .unsignedInt(ui): return CBOR.encodeVarUInt(ui)
        case let .negativeInt(ni): return CBOR.encodeNegativeInt(~Int64(bitPattern: ni))
        case let .data(d): return CBOR.encodeData(d)
        case let .utf8String(str): return str.cborEncode
        case let .array(a): return CBOR.encodeArray(a)
        case let .map(m): return CBOR.encodeMap(m)
        case let .orderedMap(m): return CBOR.encodeOrderedMap(m)
        case let .date(d): return CBOR.encodeDate(d)
        case let .tagged(t, l): return CBOR.encodeTagged(tag: t, value: l)
        case let .simple(s): return CBOR.encodeSimpleValue(s)
        case let .boolean(b): return b.cborEncode
        case .null: return CBOR.encodeNull()
        case .undefined: return CBOR.encodeUndefined()
        case .half(_): return CBOR.undefined.cborEncode
        case let .float(f): return f.cborEncode
        case let .double(d): return d.cborEncode
        case .break: return CBOR.encodeBreak()
        }
    }
    
    public var cbor: CBOR {
        self
    }
    
    public var hex: String {
        cborEncode.hex
    }
    
    public var diagnostic: String {
        cborEncode.utf8!
    }
}

extension Int: CBOREncodable {
    public var cborEncode: Data {
        if (self < 0) {
            return CBOR.encodeNegativeInt(Int64(self))
        } else {
            return CBOR.encodeVarUInt(UInt64(self))
        }
    }
    
    public var cbor: CBOR {
        if self < 0 {
            return .negativeInt(~UInt64(bitPattern: Int64(self)))
        } else {
            return .unsignedInt(UInt64(self))
        }
    }
}

extension Int: CBORDecodable {
    public static func cborDecode(_ cbor: CBOR) throws -> Int {
        switch cbor {
        case .unsignedInt(let u64):
            guard let i = Int(exactly: u64) else {
                throw CBORDecodingError.valueOutOfRange
            }
            return i
        case .negativeInt(let u64):
            guard let i = Int(exactly: u64) else {
                throw CBORDecodingError.valueOutOfRange
            }
            return -1 - i
        default:
            throw CBORDecodingError.typeMismatch
        }
    }
}

extension UInt: CBOREncodable {
    public var cborEncode: Data {
        CBOR.encodeVarUInt(UInt64(self))
    }
    
    public var cbor: CBOR {
        .unsignedInt(UInt64(self))
    }
}

extension UInt: CBORDecodable {
    public static func cborDecode(_ cbor: CBOR) throws -> UInt {
        switch cbor {
        case .unsignedInt(let u64):
            guard let i = UInt(exactly: u64) else {
                throw CBORDecodingError.valueOutOfRange
            }
            return i
        default:
            throw CBORDecodingError.typeMismatch
        }
    }
}

extension UInt8: CBOREncodable {
    public var cborEncode: Data {
        CBOR.encodeUInt8(self)
    }
    
    public var cbor: CBOR {
        .unsignedInt(UInt64(self))
    }
}

extension UInt8: CBORDecodable {
    public static func cborDecode(_ cbor: CBOR) throws -> UInt8 {
        switch cbor {
        case .unsignedInt(let u64):
            guard let i = UInt8(exactly: u64) else {
                throw CBORDecodingError.valueOutOfRange
            }
            return i
        default:
            throw CBORDecodingError.typeMismatch
        }
    }
}

extension UInt16: CBOREncodable {
    public var cborEncode: Data {
        CBOR.encodeUInt16(self)
    }
    
    public var cbor: CBOR {
        .unsignedInt(UInt64(self))
    }
}

extension UInt16: CBORDecodable {
    public static func cborDecode(_ cbor: CBOR) throws -> UInt16 {
        switch cbor {
        case .unsignedInt(let u64):
            guard let i = UInt16(exactly: u64) else {
                throw CBORDecodingError.valueOutOfRange
            }
            return i
        default:
            throw CBORDecodingError.typeMismatch
        }
    }
}

extension UInt64: CBOREncodable {
    public var cborEncode: Data {
        CBOR.encodeUInt64(self)
    }
    
    public var cbor: CBOR {
        .unsignedInt(self)
    }
}

extension UInt64: CBORDecodable {
    public static func cborDecode(_ cbor: CBOR) throws -> UInt64 {
        switch cbor {
        case .unsignedInt(let u64):
            guard let i = UInt64(exactly: u64) else {
                throw CBORDecodingError.valueOutOfRange
            }
            return i
        default:
            throw CBORDecodingError.typeMismatch
        }
    }
}

extension UInt32: CBOREncodable {
    public var cborEncode: Data {
        CBOR.encodeUInt32(self)
    }
    
    public var cbor: CBOR {
        .unsignedInt(UInt64(self))
    }
}

extension UInt32: CBORDecodable {
    public static func cborDecode(_ cbor: CBOR) throws -> UInt32 {
        switch cbor {
        case .unsignedInt(let u64):
            guard let i = UInt32(exactly: u64) else {
                throw CBORDecodingError.valueOutOfRange
            }
            return i
        default:
            throw CBORDecodingError.typeMismatch
        }
    }
}

extension String: CBOREncodable {
    public var cborEncode: Data {
        CBOR.encodeString(self)
    }
    
    public var cbor: CBOR {
        .utf8String(self)
    }
}

extension String: CBORDecodable {
    public static func cborDecode(_ cbor: CBOR) throws -> String {
        switch cbor {
        case .utf8String(let s):
            return s
        default:
            throw CBORDecodingError.typeMismatch
        }
    }
}

extension Float: CBOREncodable {
    public var cborEncode: Data {
        CBOR.encodeFloat(self)
    }
    
    public var cbor: CBOR {
        .float(self)
    }
}

extension Float: CBORDecodable {
    public static func cborDecode(_ cbor: CBOR) throws -> Float {
        switch cbor {
        case .float(let f):
            return f
        default:
            throw CBORDecodingError.typeMismatch
        }
    }
}

extension Double: CBOREncodable {
    public var cborEncode: Data {
        CBOR.encodeDouble(self)
    }
    
    public var cbor: CBOR {
        .double(self)
    }
}

extension Double: CBORDecodable {
    public static func cborDecode(_ cbor: CBOR) throws -> Double {
        switch cbor {
        case .double(let d):
            return d
        default:
            throw CBORDecodingError.typeMismatch
        }
    }
}

extension Bool: CBOREncodable {
    public var cborEncode: Data {
        CBOR.encodeBool(self)
    }
    
    public var cbor: CBOR {
        .boolean(self)
    }
}

extension Bool: CBORDecodable {
    public static func cborDecode(_ cbor: CBOR) throws -> Bool {
        switch cbor {
        case .boolean(let b):
            return b
        default:
            throw CBORDecodingError.typeMismatch
        }
    }
}

extension Array where Element: CBOREncodable {
    public func encode() -> Data {
        CBOR.encodeArray(self)
    }
}

extension Array: CBORDecodable where Element == CBOR {
    public static func cborDecode(_ cbor: CBOR) throws -> Self {
        switch cbor {
        case .array(let elements):
            return elements
        default:
            throw CBORDecodingError.typeMismatch
        }
    }
}

extension Date: CBOREncodable {
    public var cborEncode: Data {
        CBOR.encodeDate(self)
    }
    
    public var cbor: CBOR {
        .date(self)
    }
}

extension Date: CBORDecodable {
    public static func cborDecode(_ cbor: CBOR) throws -> Date {
        switch cbor {
        case .date(let d):
            return d
        default:
            throw CBORDecodingError.typeMismatch
        }
    }
}

extension Data: CBOREncodable {
    public var cborEncode: Data {
        CBOR.encodeByteString(self.map{ $0 })
    }
    
    public var cbor: CBOR {
        .data(self)
    }
}

extension Data: CBORDecodable {
    public static func cborDecode(_ cbor: CBOR) throws -> Data {
        switch cbor {
        case .data(let d):
            return d
        default:
            throw CBORDecodingError.typeMismatch
        }
    }
}

public typealias CBORCodable = CBOREncodable & CBORDecodable
