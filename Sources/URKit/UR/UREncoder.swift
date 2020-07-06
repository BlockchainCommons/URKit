//
//  UREncoder.swift
//  URKit
//
//  Created by Wolf McNally on 7/5/20.
//

import Foundation

public final class UREncoder {
    /// Encode a single-part UR.
    public static func encode(_ ur: UR) -> String {
        let body = Bytewords.encode(ur.cbor, style: .minimal)
        return encodeUR([ur.type, body])
    }

    private let ur: UR
    private let fountainEncoder: FountainEncoder

    /// Start encoding a (possibly) multi-part UR.
    public init(_ ur: UR, maxFragmentLen: Int, minFragmentLen: Int = 10, firstSeqNum: UInt32 = 0) {
        self.ur = ur
        fountainEncoder = FountainEncoder(message: ur.cbor, maxFragmentLen: maxFragmentLen, minFragmentLen: minFragmentLen, firstSeqNum: firstSeqNum)
    }

    /// `true` if the minimal number of parts to transmit the message have been
    /// generated. Parts generated when this is `true` will be fountain codes
    /// containing various mixes of the part data.
    public var isComplete: Bool { fountainEncoder.isComplete }

    /// `true` if this UR can be contained in a single part. If `true`, repeated
    /// calls to `nextPart()` will all return the same single-part UR.
    public var isSinglePart: Bool { fountainEncoder.isSinglePart }

    public func nextPart() -> String {
        let part = fountainEncoder.nextPart()
        if isSinglePart {
            return Self.encode(ur)
        } else {
            return Self.encodePart(type: ur.type, part: part)
        }
    }

    private static func encodePart(type: String, part: FountainEncoder.Part) -> String {
        let seq = "\(part.seqNum)-\(part.seqLen)"
        let body = Bytewords.encode(part.cbor, style: .minimal)
        return encodeUR([type, seq, body])
    }

    private static func encodeURI(scheme: String, pathComponents: [String]) -> String {
        let path = pathComponents.joined(separator: "/")
        return [scheme, path].joined(separator: ":")
    }

    private static func encodeUR(_ pathComponents: [String]) -> String {
        encodeURI(scheme: "ur", pathComponents: pathComponents)
    }
}
