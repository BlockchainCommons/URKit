//
//  TestUtils.swift
//  URKit
//
//  Created by Wolf McNally on 7/5/20.
//

import Foundation

@testable import URKit

func makeMessage(len: Int, seed: String = "Wolf") -> Data {
    let rng = Xoshiro256(string: seed)
    return rng.nextData(count: len)
}

func makeMessageUR(len: Int, seed: String = "Wolf") -> UR {
    let message = makeMessage(len: len, seed: seed)
    let cbor = CBOR.byteString(message.bytes).encode().data
    return try! UR(type: "bytes", cbor: cbor)
}
