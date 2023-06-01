//
//  FountainDecoder.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation
import BCCrypto

// Implements Luby transform code rateless decoding
// https://en.wikipedia.org/wiki/Luby_transform_code

public typealias PartIndexes = Set<Int>

public enum FountainDecoderError: LocalizedError {
    case invalidPart
    case invalidChecksum
    
    public var errorDescription: String? {
        switch self {
        case .invalidPart:
            return "FountainDecoder: Invalid part."
        case .invalidChecksum:
            return "FountainDecoder: Invalid checksum."
        }
    }
}

public final class FountainDecoder {
    typealias PartDict = [PartIndexes: Part]

    public var expectedPartCount: Int! { return expectedPartIndexes?.count }
    public private(set) var receivedPartIndexes: PartIndexes = []
    public private(set) var lastPartIndexes: PartIndexes!
    public private(set) var processedPartsCount = 0
    public private(set) var result: Result<Data, Error>?

    var expectedPartIndexes: PartIndexes!
    var expectedFragmentLen: Int!
    var expectedMessageLen: Int!
    var expectedChecksum: UInt32!

    var simpleParts: PartDict = [:]
    var mixedParts: PartDict = [:]
    var queuedParts: [Part] = []
    
    private var fragmentChooser: FragmentChooser!

    public var estimatedPercentComplete: Double {
        guard result == nil else { return 1 }
        guard let expectedPartCount = expectedPartCount else { return 0 }
        let estimatedInputParts = Double(expectedPartCount) * 1.75
        return min(0.99, Double(processedPartsCount) / estimatedInputParts)
    }

    struct Part {
        let partIndexes: PartIndexes
        let data: Data

        var index: Int { partIndexes.first! }

        init(_ p: FountainEncoder.Part, partIndexes: PartIndexes) {
            data = p.data
            self.partIndexes = partIndexes
        }

        init(partIndexes: PartIndexes, data: Data) {
            self.partIndexes = partIndexes
            self.data = data
        }

        var isSimple: Bool {
            partIndexes.count == 1
        }
    }

    public init() {
    }

    public func receivePart(_ encoderPart: FountainEncoder.Part) -> Bool {
        // Don't process the part if we're already done
        guard result == nil else { return false }

        // Don't continue if this part doesn't validate
        guard validatePart(encoderPart) else { return false }

        if fragmentChooser == nil {
            self.fragmentChooser = FragmentChooser(seqLen: encoderPart.seqLen, checksum: encoderPart.checksum)
        }

        // Add this part to the queue
        let partIndexes = fragmentChooser.chooseFragments(at: encoderPart.seqNum)
        let part = Part(encoderPart, partIndexes: partIndexes)
        lastPartIndexes = part.partIndexes
        enqueue(part)

        // Process the queue until we're done or the queue is empty
        while result == nil && !queuedParts.isEmpty {
            processQueueItem()
        }

        // Keep track of how many parts we've processed
        processedPartsCount += 1
        //printPartEnd()
        return true
    }

    private func enqueue(_ part: Part) {
        queuedParts.append(part)
    }

    func printPartEnd() {
        let parts = expectedPartCount != nil ? String(expectedPartCount) : "nil"
        let percent = Int((estimatedPercentComplete * 100).rounded())
        print("processed: \(processedPartsCount), expected: \(parts), received: \(receivedPartIndexes.count), percent: \(percent)%")
    }

    func printPart(_ part: Part) {
        let indexes = Array(part.partIndexes).sorted()
        print("part indexes: \(indexes)")
    }

    private func resultDescription() -> String {
        let desc: String
        switch result {
        case nil:
            desc = "nil"
        case let .success(message)?:
            desc = "\(message.count) bytes"
        case let .failure(error)?:
            desc = error.localizedDescription
        }
        return desc
    }

    func printState() {
        let parts = expectedPartCount != nil ? String(expectedPartCount) : "nil"
        let received = Array(receivedPartIndexes).sorted()
        let mixed = mixedParts.keys.map( { Array($0).sorted() } ).sorted(by: { $0.lexicographicallyPrecedes($1) } )
        let queued = queuedParts.count
        print("parts: \(parts), received: \(received), mixed: \(mixed), queued: \(queued), result: \(resultDescription())")
    }

    private func processQueueItem() {
        let part = queuedParts.removeFirst()
        //printPart(part)
        if part.isSimple {
            processSimplePart(part)
        } else {
            processMixedPart(part)
        }
        //printState()
    }

    private func reduceMixed(by part: Part) {
        // Reduce all the current mixed parts by the given part
        let reducedParts = mixedParts.values.map {
            reducePart($0, by: part)
        }

        // Collect all the remaining mixed parts
        var newMixed: PartDict = [:]
        reducedParts.forEach { reducedPart in
            // If this reduced part is now simple
            if reducedPart.isSimple {
                // Add it to the queue
                enqueue(reducedPart)
            } else {
                // Otherwise, add it to the list of current mixed parts
                newMixed[reducedPart.partIndexes] = reducedPart
            }
        }
        mixedParts = newMixed
    }

    // Reduce part `a` by part `b`
    private func reducePart(_ a: Part, by b: Part) -> Part {
        // If the fragments mixed into `b` are a strict (proper) subset of those in `a`...
        if b.partIndexes.isStrictSubset(of: a.partIndexes) {
            // The new fragments in the revised part are `a` - `b`.
            let newIndexes = a.partIndexes.subtracting(b.partIndexes)
            // The new data in the revised part are `a` XOR `b`
            let newData = a.data.xor(with: b.data)
            return Part(partIndexes: newIndexes, data: newData)
        } else {
            // `a` is not reducable by `b`, so return a
            return a
        }
    }

    private func processSimplePart(_ part: Part) {
        // Don't process duplicate parts
        let fragmentIndex = part.index
        guard !receivedPartIndexes.contains(fragmentIndex) else { return }

        // Record this part
        simpleParts[part.partIndexes] = part
        receivedPartIndexes.insert(fragmentIndex)

        // If we've received all the parts
        if receivedPartIndexes == expectedPartIndexes {
            // Reassemble the message from its fragments
            let sortedParts = Array(simpleParts.values).sorted { $0.index < $1.index }
            let fragments = sortedParts.map { $0.data }
            let message = Self.joinFragments(fragments, messageLen: expectedMessageLen)

            // Verify the message checksum and note success or failure
            let checksum = crc32(message)
            if checksum == expectedChecksum {
                result = .success(message)
            } else {
                result = .failure(FountainDecoderError.invalidChecksum)
            }
        } else {
            // Reduce all the mixed parts by this part
            reduceMixed(by: part)
        }
    }

    private func processMixedPart(_ part: Part) {
        // Don't process duplicate parts
        guard !mixedParts.keys.contains(part.partIndexes) else { return }

        // Reduce this part by all the others
        let p = [simpleParts.values, mixedParts.values].joined().reduce(part) {
            reducePart($0, by: $1)
        }

        // If the part is now simple
        if p.isSimple {
            // Add it to the queue
            enqueue(p)
        } else {
            // Reduce all the mixed parts by this one
            reduceMixed(by: p)
            // Record this new mixed part
            mixedParts[p.partIndexes] = p
        }
    }

    private func validatePart(_ part: FountainEncoder.Part) -> Bool {
        // If this is the first part we've seen
        if expectedPartIndexes == nil {
            // Record the things that all the other parts we see will have to match to be valid.
            expectedPartIndexes = Set(0 ..< part.seqLen)
            expectedMessageLen = part.messageLen
            expectedChecksum = part.checksum
            expectedFragmentLen = part.data.count
        } else {
            // If this part's values don't match the first part's values
            guard expectedPartCount == part.seqLen,
                  expectedMessageLen == part.messageLen,
                  expectedChecksum == part.checksum,
                  expectedFragmentLen == part.data.count
            else {
                // Throw away the part
                return false
            }
        }
        // This part should be processed
        return true
    }

    // Join all the fragments of a message together, throwing away any padding
    static func joinFragments(_ fragments: [Data], messageLen: Int) -> Data {
        var message = Data(fragments.joined())
        let padding = message.count - messageLen
        message.removeLast(padding)
        return message
    }
}
