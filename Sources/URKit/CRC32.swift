//
//  CRC32.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation

// Based on: https://gist.github.com/01GOD/3e6bb0b19a0caf138dd4b57e22122ae1

class CRC32 {
    static var table: [UInt32] = {
        (0...255).map { i -> UInt32 in
            (0..<8).reduce(UInt32(i), { c, _ in
                (c % 2 == 0) ? (c >> 1) : (0xEDB88320 ^ (c >> 1))
            })
        }
    }()

    static func checksum(data: Data) -> UInt32 {
        ~(data.reduce(~UInt32(0), { crc, byte in
            (crc >> 8) ^ table[(Int(crc) ^ Int(byte)) & 0xFF]
        }))
    }

    static func checksum(string: String) -> UInt32 {
        checksum(data: string.utf8)
    }
}
