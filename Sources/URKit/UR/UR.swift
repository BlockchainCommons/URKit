//
//  UR.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation

public struct UR: Equatable {
    let type: String
    let cbor: Data

    public enum Error: Swift.Error {
        case invalidType
    }

    public init(type: String, cbor: Data) throws {
        guard type.isURType else { throw Error.invalidType }
        self.type = type
        self.cbor = cbor
    }
}

//public struct URSomething {
//    public let type: String
//    public let content: Content
//
//    public enum Content {
//        case complete(Data)
//        case part(FountainEncoder.Part)
//    }
//
//    enum Error: Swift.Error {
//        case invalidScheme
//        case invalidNumberOfPathComponents
//        case invalidBody
//        case invalidFragment
//        case invalidType
//        case invalidSequenceComponent
//    }
//
//    public init(type: String, cbor: Data) throws {
//        guard type.isURType else { throw Error.invalidType }
//        self.type = type
//        self.content = .complete(cbor)
//    }
//
//    public static func encode(type: String, cbor: Data) throws -> UR {
//        return try UR(type: type, cbor: cbor)
//    }
//
//    public init(_ string: String) throws {
//        // Don't consider case
//        let lowered = string.lowercased()
//
//        // Validate URI scheme
//        guard lowered.hasPrefix("ur:") else { throw Error.invalidScheme }
//        let path = lowered.dropFirst(3)
//
//        // Split the remainder into path components
//        let components = path.split(separator: "/").map { String($0) }
//
//        guard (2...3).contains(components.count) else {
//            throw Error.invalidNumberOfPathComponents
//        }
//
//        // Validate the type component
//        let type = components.first!
//        guard type.isURType else { throw Error.invalidType }
//
//        switch components.count {
//        case 2:
//            try self.init(type: type, body: components[1])
//        case 3:
//            try self.init(type: type, seq: components[1], fragment: components[2])
//        default:
//            fatalError()
//        }
//    }
//
//    public init(type: String, content: Content) {
//        self.type = type
//        self.content = content
//    }
//
//    init(type: String, body: String) throws {
//        let content = try Content.complete(Bytewords.decode(body))
//        self.init(type: type, content: content)
//    }
//
//    init(type: String, seq: String, fragment: String) throws {
//        let (seqNum, seqLen) = try Self.parseSequenceComponent(seq)
//        let cbor = try Bytewords.decode(fragment)
//        let part = try FountainEncoder.Part(cbor: cbor)
//        guard seqNum == part.seqNum, seqLen == part.seqLen else {
//            throw Error.invalidFragment
//        }
//        self.init(type: type, content: .part(part))
//    }
//
//    var string: String {
//        var result = "ur:\(type)/"
//
//        switch content {
//        case .complete(let data):
//            result.append(Bytewords.encode(data, style: .minimal))
//        case .part(let part):
//            result.append("\(part.seqNum)of\(part.seqLen)")
//            result.append(Bytewords.encode(part.cbor, style: .minimal))
//        }
//
//        return result
//    }
//}
