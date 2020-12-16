//
//  UR.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation

public struct UR: Equatable {
    public let type: String
    public let cbor: Data

    public enum Error: Swift.Error {
        case invalidType
    }

    public init(type: String, cbor: Data) throws {
        guard type.isURType else { throw Error.invalidType }
        self.type = type
        self.cbor = cbor
    }

    public init(type: String, cbor: [UInt8]) throws {
        try self.init(type: type, cbor: Data(cbor))
    }

    public init(type: String, cbor: CBOR) throws {
        try self.init(type: type, cbor: cbor.encode())
    }
}
