// From: https://github.com/myfreeweb/SwiftCBOR
// License: Public Domain

import Foundation

public protocol CBOREncodable: Hashable {
    func cborEncode() -> Data
}

extension CBOR: CBOREncodable {
    /// Encodes a wrapped CBOR value. CBOR.half (Float16) is not supported and encodes as `undefined`.
    public func cborEncode() -> Data {
        switch self {
        case let .unsignedInt(ui): return CBOR.encodeVarUInt(ui)
        case let .negativeInt(ni): return CBOR.encodeNegativeInt(~Int64(bitPattern: ni))
        case let .byteString(bs): return CBOR.encodeData(bs)
        case let .utf8String(str): return str.cborEncode()
        case let .array(a): return CBOR.encodeArray(a)
        case let .map(m): return CBOR.encodeMap(m)
        case let .orderedMap(m): return CBOR.encodeOrderedMap(m)
        case let .date(d): return CBOR.encodeDate(d)
        case let .tagged(t, l): return CBOR.encodeTagged(tag: t, value: l)
        case let .simple(s): return CBOR.encodeSimpleValue(s)
        case let .boolean(b): return b.cborEncode()
        case .null: return CBOR.encodeNull()
        case .undefined: return CBOR.encodeUndefined()
        case .half(_): return CBOR.undefined.cborEncode()
        case let .float(f): return f.cborEncode()
        case let .double(d): return d.cborEncode()
        case .break: return CBOR.encodeBreak()
        }
    }
}

extension Int: CBOREncodable {
    public func cborEncode() -> Data {
        if (self < 0) {
            return CBOR.encodeNegativeInt(Int64(self))
        } else {
            return CBOR.encodeVarUInt(UInt64(self))
        }
    }
}

extension UInt: CBOREncodable {
    public func cborEncode() -> Data {
        return CBOR.encodeVarUInt(UInt64(self))
    }
}

extension UInt8: CBOREncodable {
    public func cborEncode() -> Data {
        return CBOR.encodeUInt8(self)
    }
}


extension UInt16: CBOREncodable {
    public func cborEncode() -> Data {
        return CBOR.encodeUInt16(self)
    }
}


extension UInt64: CBOREncodable {
    public func cborEncode() -> Data {
        return CBOR.encodeUInt64(self)
    }
}

extension UInt32: CBOREncodable {
    public func cborEncode() -> Data {
        return CBOR.encodeUInt32(self)
    }
}

extension String: CBOREncodable {
    public func cborEncode() -> Data {
        return CBOR.encodeString(self)
    }
}

extension Float: CBOREncodable {
    public func cborEncode() -> Data {
        return CBOR.encodeFloat(self)
    }
}

extension Double: CBOREncodable {
    public func cborEncode() -> Data {
        return CBOR.encodeDouble(self)
    }
}

extension Bool: CBOREncodable {
    public func cborEncode() -> Data {
        return CBOR.encodeBool(self)
    }
}

extension Array where Element: CBOREncodable {
    public func encode() -> Data {
        return CBOR.encodeArray(self)
    }
}

extension Date: CBOREncodable {
    public func cborEncode() -> Data {
        return CBOR.encodeDate(self)
    }
}

extension Data: CBOREncodable {
    public func cborEncode() -> Data {
        return CBOR.encodeByteString(self.map{ $0 })
    }
}
