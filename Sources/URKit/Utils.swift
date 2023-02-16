import Foundation

func toHex(byte: UInt8) -> String {
    String(format: "%02x", byte)
}

func toHex(data: Data) -> String {
    data.reduce(into: "") {
        $0 += toHex(byte: $1)
    }
}

extension Data {
    var hex: String {
        toHex(data: self)
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
    
    var utf8Data: Data {
        data(using: .utf8)!
    }
}

// Based on: https://gist.github.com/01GOD/3e6bb0b19a0caf138dd4b57e22122ae1
enum CRC32 {
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
        checksum(data: string.utf8Data)
    }
}
