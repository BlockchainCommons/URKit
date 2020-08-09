//
//  FountainEncoder.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation

// Implements Luby transform code rateless coding
// https://en.wikipedia.org/wiki/Luby_transform_code

public final class FountainEncoder {
    let messageLen: Int
    let checksum: UInt32
    let fragmentLen: Int
    let fragments: [Data]
    public private(set) var seqNum: UInt32
    public private(set) var lastPartIndexes: PartIndexes!
    public var seqLen: Int { fragments.count }

    /// This becomes `true` when the minimum number of parts
    /// to relay the complete message have been generated
    public var isComplete: Bool { seqNum >= seqLen }

    /// True if only a single part will be generated.
    public var isSinglePart: Bool { seqLen == 1 }

    public struct Part: CustomStringConvertible, Codable {
        public let seqNum: UInt32
        public let seqLen: Int
        public let messageLen: Int
        public let checksum: UInt32
        public let data: Data

        public init(seqNum: UInt32, seqLen: Int, messageLen: Int, checksum: UInt32, data: Data) {
            self.seqNum = seqNum
            self.seqLen = seqLen
            self.messageLen = messageLen
            self.checksum = checksum
            self.data = data
        }

        public enum Error: Swift.Error {
            case invalidPartHeader
        }

        public init(cbor: Data) throws {
            guard let decoded = try! CBOR.decode(cbor.bytes) else { throw Error.invalidPartHeader }
            guard case let CBOR.array(a) = decoded,
                  a.count == 5 else { throw Error.invalidPartHeader }
            var seqNum: UInt32!
            var seqLen: Int!
            var messageLen: Int!
            var checksum: UInt32!
            var data: Data!
            for (index, elem) in a.enumerated() {
                switch index {
                case 0:
                    guard case let CBOR.unsignedInt(n) = elem else { throw Error.invalidPartHeader }
                    seqNum = UInt32(n)
                case 1:
                    guard case let CBOR.unsignedInt(n) = elem else { throw Error.invalidPartHeader }
                    seqLen = Int(n)
                case 2:
                    guard case let CBOR.unsignedInt(n) = elem else { throw Error.invalidPartHeader }
                    messageLen = Int(n)
                case 3:
                    guard case let CBOR.unsignedInt(n) = elem else { throw Error.invalidPartHeader }
                    checksum = UInt32(n)
                case 4:
                    guard case let CBOR.byteString(d) = elem else { throw Error.invalidPartHeader }
                    data = Data(d)
                default:
                    fatalError()
                }
            }
            guard seqNum != nil, seqLen != nil, messageLen != nil, checksum != nil, data != nil else { throw Error.invalidPartHeader }
            self.init(seqNum: seqNum, seqLen: seqLen, messageLen: messageLen, checksum: checksum, data: data)
        }

        public var description: String {
            "seqNum:\(seqNum), seqLen:\(seqLen), messageLen:\(messageLen), checksum:\(checksum), data:\(data.hex)"
        }

        public var cbor: Data {
            let wrapper: CBOR = [
                .unsignedInt(UInt64(seqNum)),
                .unsignedInt(UInt64(seqLen)),
                .unsignedInt(UInt64(messageLen)),
                .unsignedInt(UInt64(checksum)),
                .byteString(data.bytes)
            ]
            return Data(wrapper.encode())
        }
    }

    public init(message: Data, maxFragmentLen: Int, firstSeqNum: UInt32 = 0, minFragmentLen: Int = 10) {
        assert(message.count <= UInt32.max)
        messageLen = message.count
        checksum = CRC32.checksum(data: message)
        fragmentLen = Self.findNominalFragmentLength(messageLen: message.count, minFragmentLen: minFragmentLen, maxFragmentLen: maxFragmentLen)
        fragments = Self.partitionMessage(message, fragmentLen: fragmentLen)
        seqNum = firstSeqNum
    }

    public func nextPart() -> Part {
        seqNum &+= 1 // wrap at period 2^32
        lastPartIndexes = chooseFragments(seqNum: seqNum, seqLen: seqLen, checksum: checksum)
        let mixed = mix(partIndexes: lastPartIndexes)
        return Part(seqNum: seqNum, seqLen: seqLen, messageLen: messageLen, checksum: checksum, data: mixed)
    }

    private func mix(partIndexes: PartIndexes) -> Data {
        partIndexes.reduce(into: Data(repeating: 0, count: fragmentLen)) { result, index in
            fragments[index].xor(into: &result)
        }
    }

    static func partitionMessage(_ message: Data, fragmentLen: Int) -> [Data] {
        var remaining = message
        var fragments: [Data] = []
        while !remaining.isEmpty {
            var fragment = remaining.prefix(fragmentLen)
            remaining.removeFirst(fragment.count)
            let padding = fragmentLen - fragment.count
            if padding > 0 {
                fragment.append(Data(repeating: 0, count: padding))
            }
            fragments.append(fragment)
        }
        return fragments
    }

    static func findNominalFragmentLength(messageLen: Int, minFragmentLen: Int, maxFragmentLen: Int) -> Int {
        precondition(messageLen > 0)
        precondition(minFragmentLen > 0)
        precondition(maxFragmentLen >= minFragmentLen)
        let maxFragmentCount = messageLen / minFragmentLen
        var fragmentLen: Int!
        for fragmentCount in 1 ... maxFragmentCount {
            fragmentLen = Int(ceil(Double(messageLen) / Double(fragmentCount)))
            if fragmentLen <= maxFragmentLen {
                break
            }
        }
        return fragmentLen
    }
}
