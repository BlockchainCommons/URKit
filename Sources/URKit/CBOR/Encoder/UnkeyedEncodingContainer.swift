// From: https://github.com/myfreeweb/SwiftCBOR
// License: Public Domain

import Foundation

extension _CBOREncoder {
    final class UnkeyedContainer {
        private var storage: [CBOREncodingContainer] = []
        private var context: CBORContext

        var count: Int {
            return storage.count
        }

        var codingPath: [CodingKey]

        var nestedCodingPath: [CodingKey] {
            return self.codingPath + [AnyCodingKey(intValue: self.count)!]
        }

        var userInfo: [CodingUserInfoKey: Any]

        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any], _ context: CBORContext) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.context = context
        }
    }
}

extension _CBOREncoder.UnkeyedContainer: UnkeyedEncodingContainer {
    func encodeNil() throws {
        var container = self.nestedSingleValueContainer(context)
        try container.encodeNil()
    }

    func encode<T: Encodable>(_ value: T) throws {
        var container = self.nestedSingleValueContainer(context)
        try container.encode(value)
    }

    private func nestedSingleValueContainer(_ context: CBORContext) -> SingleValueEncodingContainer {
        let container = _CBOREncoder.SingleValueContainer(codingPath: self.nestedCodingPath, userInfo: self.userInfo, context)
        self.storage.append(container)

        return container
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let container = _CBOREncoder.KeyedContainer<NestedKey>(codingPath: self.nestedCodingPath, userInfo: self.userInfo, context)
        self.storage.append(container)

        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let container = _CBOREncoder.UnkeyedContainer(codingPath: self.nestedCodingPath, userInfo: self.userInfo, context)
        self.storage.append(container)

        return container
    }

    func superEncoder() -> Encoder {
        fatalError("Unimplemented") // FIXME
    }
}

extension _CBOREncoder.UnkeyedContainer: CBOREncodingContainer {
    var data: Data {
        // TODO: Check that this works for all sizes of array
        var data = storage.count.cborEncode(.binary)
        data[0] = data[0] | 0b100_00000
        for container in storage {
            data.append(contentsOf: container.data)
        }
        return data
    }
}
