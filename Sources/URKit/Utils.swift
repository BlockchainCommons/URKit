//
//  Utils.swift
//  FountainCodes
//
//  Created by Wolf McNally on 7/2/20.
//

import Foundation
import CryptoKit

extension Collection where Element == UInt8 {
    var hex: String { self.map { String(format: "%02hhx", $0) }.joined() }
}

extension SHA256Digest {
    var data: Data { withUnsafeBytes { Data(bytes: $0.baseAddress!, count: SHA256Digest.byteCount) } }
    var hex: String { data.hex }
}

extension UInt32 {
    var data: Data {
        let size = MemoryLayout<UInt32>.size
        var d = Data()
        d.reserveCapacity(size)
        for i in 0 ..< size {
            let o = (8 * (3 - i))
            let n = self >> o
            let c = UInt8(truncatingIfNeeded: n)
            d.append(c)
        }
        return d
    }

    var hex: String { data.hex }
}

extension String {
    var utf8: Data {
        return data(using: .utf8)!
    }
}

extension Data {
    var utf8: String {
        String(data: self, encoding: .utf8)!
    }

    var uint32: UInt32 {
        let size = MemoryLayout<UInt32>.size
        assert(count >= size)
        var result: UInt32 = 0
        withUnsafeBytes { p in
            for i in 0 ..< size {
                result <<= 8
                result |= UInt32(p[i])
            }
        }
        return result
    }

    var bytes: [UInt8] {
        var b: [UInt8] = []
        b.append(contentsOf: self)
        return b
    }
}

extension Encodable {
    var json: Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try! encoder.encode(self)
    }

    var jsonString: String {
        json.utf8
    }
}

func join<C: Collection, T>(_ elements: C...) -> [T] where C.Element == T{
    elements.reduce(into: []) {
        $0.append(contentsOf: $1)
    }
}

extension Array where Element == UInt8 {
    var data: Data {
        Data(self)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension String {
    func chunked(into size: Int) -> [String] {
        var result: [String] = []
        var chunk = ""
        for c in self {
            chunk.append(c)
            if chunk.count == size {
                result.append(chunk)
                chunk = ""
            }
        }
        if !chunk.isEmpty {
            result.append(chunk)
        }
        return result
    }
}
