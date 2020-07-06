//
//  FountainUtils.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation

extension Data {
    func xor(into d: inout Data) {
        assert(count == d.count)
        withUnsafeBytes { selfBytes in
            d.withUnsafeMutableBytes { dBytes in
                for i in (0..<count) {
                    dBytes[i] ^= selfBytes[i]
                }
            }
        }
    }

    func xor(with d: Data) -> Data {
        var b = self
        d.xor(into: &b)
        return b
    }
}

func chooseDegree(seqLen: Int, rng: Xoshiro256) -> Int {
    let degreeProbabilities = (1 ... seqLen).map { 1 / Double($0) }
    let degreeChooser = RandomSampler(degreeProbabilities)
    return degreeChooser.next(rng.nextDouble) + 1
}

func chooseFragments(seqNum: UInt32, seqLen: Int, checksum: UInt32) -> Set<Int> {
    // The first `seqLen` parts are the "pure" fragments, not mixed with any
    // others. This means that if you only generate the first `seqLen` parts,
    // then you have all the parts you need to decode the message.
    if seqNum <= seqLen {
        return Set([Int(seqNum) - 1])
    } else {
        let seed = Data([seqNum.data, checksum.data].joined())
        let rng = Xoshiro256(data: seed)
        let degree = chooseDegree(seqLen: seqLen, rng: rng)
        let indexes = Array(0 ..< seqLen)
        let shuffledIndexes = shuffled(indexes, rng: rng)
        return Set(shuffledIndexes.prefix(degree))
    }
}

// Fisher-Yates shuffle
func shuffled<T>(_ items: [T], rng: Xoshiro256) -> [T] {
    var remaining = items;
    var result: [T] = [];
    result.reserveCapacity(remaining.count)
    while !remaining.isEmpty {
        let index = rng.nextInt(in: 0 ..< remaining.count)
        let item = remaining.remove(at: index)
        result.append(item)
    }
    return result
}
