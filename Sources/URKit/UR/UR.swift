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
}
