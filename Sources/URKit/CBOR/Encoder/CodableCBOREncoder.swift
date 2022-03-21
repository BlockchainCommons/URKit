// From: https://github.com/myfreeweb/SwiftCBOR
// License: Public Domain

import Foundation

public class CodableCBOREncoder {
    public init() {}

    public func encode(_ value: Encodable, _ context: CBORContext) throws -> Data {
        let encoder = _CBOREncoder()
        if let dateVal = value as? Date {
            return Data(CBOR.encodeDate(dateVal, context))
        } else if let dataVal = value as? Data {
            return Data(CBOR.encodeData(dataVal, context))
        }
        try value.encode(to: encoder)
        return encoder.data
    }
}

final class _CBOREncoder {
    var codingPath: [CodingKey] = []

    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    let context: CBORContext = .binary

    fileprivate var container: CBOREncodingContainer? {
        willSet {
            precondition(self.container == nil)
        }
    }

    var data: Data {
        return container?.data ?? Data()
    }
}

extension _CBOREncoder: Encoder {
    fileprivate func assertCanCreateContainer() {
        precondition(self.container == nil)
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        assertCanCreateContainer()

        let container = KeyedContainer<Key>(codingPath: self.codingPath, userInfo: self.userInfo, context)
        self.container = container

        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        assertCanCreateContainer()

        let container = UnkeyedContainer(codingPath: self.codingPath, userInfo: self.userInfo, context)
        self.container = container

        return container
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        assertCanCreateContainer()

        let container = SingleValueContainer(codingPath: self.codingPath, userInfo: self.userInfo, context)
        self.container = container

        return container
    }
}

protocol CBOREncodingContainer: AnyObject {
    var data: Data { get }
}
