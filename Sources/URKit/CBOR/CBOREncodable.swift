// From: https://github.com/myfreeweb/SwiftCBOR
// License: Public Domain

import Foundation
import WolfBase

public enum CBORContext {
    case binary
    case diagnostic
}

public protocol CBOREncodable: Hashable {
    func cborEncode(_ context: CBORContext) -> Data
}

extension CBOR: CBOREncodable {
    /// Encodes a wrapped CBOR value. CBOR.half (Float16) is not supported and encodes as `undefined`.
    public func cborEncode(_ context: CBORContext) -> Data {
        switch self {
        case let .unsignedInt(ui): return CBOR.encodeVarUInt(ui, context)
        case let .negativeInt(ni): return CBOR.encodeNegativeInt(~Int64(bitPattern: ni), context)
        case let .data(d): return CBOR.encodeData(d, context)
        case let .utf8String(str): return str.cborEncode(context)
        case let .array(a): return CBOR.encodeArray(a, context)
        case let .map(m): return CBOR.encodeMap(m, context)
        case let .orderedMap(m): return CBOR.encodeOrderedMap(m, context)
        case let .date(d): return CBOR.encodeDate(d, context)
        case let .tagged(t, l): return CBOR.encodeTagged(tag: t, value: l, context)
        case let .simple(s): return CBOR.encodeSimpleValue(s, context)
        case let .boolean(b): return b.cborEncode(context)
        case .null: return CBOR.encodeNull(context)
        case .undefined: return CBOR.encodeUndefined(context)
        case .half(_): return CBOR.undefined.cborEncode(context)
        case let .float(f): return f.cborEncode(context)
        case let .double(d): return d.cborEncode(context)
        case .break: return CBOR.encodeBreak(context)
        }
    }
    
    public var encoded: Data {
        cborEncode(.binary)
    }
    
    public var hex: String {
        encoded.hex
    }
    
    public var diagnostic: String {
        cborEncode(.diagnostic).utf8!
    }
}

extension Int: CBOREncodable {
    public func cborEncode(_ context: CBORContext) -> Data {
        if (self < 0) {
            return CBOR.encodeNegativeInt(Int64(self), context)
        } else {
            return CBOR.encodeVarUInt(UInt64(self), context)
        }
    }
}

extension UInt: CBOREncodable {
    public func cborEncode(_ context: CBORContext) -> Data {
        return CBOR.encodeVarUInt(UInt64(self), context)
    }
}

extension UInt8: CBOREncodable {
    public func cborEncode(_ context: CBORContext) -> Data {
        return CBOR.encodeUInt8(self, context)
    }
}


extension UInt16: CBOREncodable {
    public func cborEncode(_ context: CBORContext) -> Data {
        return CBOR.encodeUInt16(self, context)
    }
}


extension UInt64: CBOREncodable {
    public func cborEncode(_ context: CBORContext) -> Data {
        return CBOR.encodeUInt64(self, context)
    }
}

extension UInt32: CBOREncodable {
    public func cborEncode(_ context: CBORContext) -> Data {
        return CBOR.encodeUInt32(self, context)
    }
}

extension String: CBOREncodable {
    public func cborEncode(_ context: CBORContext) -> Data {
        return CBOR.encodeString(self, context)
    }
}

extension Float: CBOREncodable {
    public func cborEncode(_ context: CBORContext) -> Data {
        return CBOR.encodeFloat(self, context)
    }
}

extension Double: CBOREncodable {
    public func cborEncode(_ context: CBORContext) -> Data {
        return CBOR.encodeDouble(self, context)
    }
}

extension Bool: CBOREncodable {
    public func cborEncode(_ context: CBORContext) -> Data {
        return CBOR.encodeBool(self, context)
    }
}

extension Array where Element: CBOREncodable {
    public func encode(_ context: CBORContext) -> Data {
        return CBOR.encodeArray(self, context)
    }
}

extension Date: CBOREncodable {
    public func cborEncode(_ context: CBORContext) -> Data {
        return CBOR.encodeDate(self, context)
    }
}

extension Data: CBOREncodable {
    public func cborEncode(_ context: CBORContext) -> Data {
        return CBOR.encodeByteString(self.map{ $0 }, context)
    }
}
