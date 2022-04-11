//
//  UR.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation

public enum URError: LocalizedError {
    case invalidType
    
    public var errorDescription: String? {
        switch self {
        case .invalidType:
            return "Invalid UR type."
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

    public init(type: String, cbor: [UInt8]) throws {
        try self.init(type: type, cbor: Data(cbor))
    }

    public init(type: String, cbor: CBOR) throws {
        try self.init(type: type, cbor: cbor.cborEncode)
    }
    
    public init(urString: String) throws {
        self = try URDecoder.decode(urString)
    }
    
    public var string: String {
        UREncoder.encode(self)
    }
    
    public var qrString: String {
        string.uppercased()
    }
    
    public var qrData: Data {
        qrString.data(using: .utf8)!
    }
    
    public var description: String {
        string
    }
}
