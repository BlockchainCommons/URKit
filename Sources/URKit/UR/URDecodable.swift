import Foundation
import DCBOR

public protocol URDecodable: CBORTaggedDecodable {
    static func decodeUR(_ ur: UR) throws -> Self
}

public extension URDecodable {
    static func decodeUR(_ ur: UR) throws -> Self {
        try ur.checkType(Self.cborTag.name!)
        return try Self(untaggedCBORData: ur.cborData)
    }
    
    static func decodeUR(_ urString: String) throws -> Self {
        try decodeUR(UR(urString: urString))
    }
}
