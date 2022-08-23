//
//  UR.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation

public enum URError: LocalizedError {
    case invalidType
    case unexpectedType
    
    public var errorDescription: String? {
        switch self {
        case .invalidType:
            return "Invalid UR type."
        case .unexpectedType:
            return "Unexpected UR type."
        }
    }
}

public struct UR: Equatable, CustomStringConvertible {
    public let type: String
    public let cbor: Data
    
    public init(type: String, cbor: Data) throws {
        guard type.isURType else { throw URError.invalidType }
        self.type = type
        self.cbor = cbor
    }
}

public extension UR {
    init(type: String, cbor: [UInt8]) throws {
        try self.init(type: type, cbor: Data(cbor))
    }
    
    init(type: String, cbor: CBOR) throws {
        try self.init(type: type, cbor: cbor.cborEncode)
    }
    
    init(type: CBOR.Tag, cbor: Data) throws {
        try self.init(type: type.urType, cbor: cbor)
    }
    
    init(type: CBOR.Tag, cbor: [UInt8]) throws {
        try self.init(type: type.urType, cbor: cbor)
    }
    
    init(type: CBOR.Tag, cbor: CBOR) throws {
        try self.init(type: type.urType, cbor: cbor)
    }
}

public extension UR {
    init(urString: String) throws {
        self = try URDecoder.decode(urString)
    }
}

public extension UR {
    var string: String {
        UREncoder.encode(self)
    }
    
    var qrString: String {
        string.uppercased()
    }
    
    var qrData: Data {
        qrString.data(using: .utf8)!
    }
    
    var description: String {
        string
    }

    func checkType(_ type: String) throws {
        guard self.type == type else {
            throw URError.unexpectedType
        }
    }
    
    func checkType(_ tag: CBOR.Tag) throws {
        try self.checkType(tag.urType)
    }
}
