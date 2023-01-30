import Foundation
import DCBOR

public protocol URDecodable: TaggedCBORDecodable {
    static var urType: String { get }
    static func decodeUR(_ ur: UR) throws -> Self
}

public extension URDecodable {
    static func decodeUR(_ ur: UR) throws -> Self {
        try ur.checkType(Self.urType)
        return try decodeUntaggedCBOR(ur.cborData)
    }
    
    static func decodeUR(_ urString: String) throws -> Self {
        try decodeUR(UR(urString: urString))
    }
}
