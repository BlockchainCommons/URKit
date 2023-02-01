//
//  UR.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation
import DCBOR

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
    public let cborData: Data
    
    public init(type: String, cborData: Data) throws {
        guard type.isURType else { throw URError.invalidType }
        self.type = type
        self.cborData = cborData
    }
    
    public init<T>(type: String, untaggedCBOR: T) throws where T: CBOREncodable {
        try self.init(type: type, cborData: untaggedCBOR.cborData)
    }

    public init(urString: String) throws {
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
}
