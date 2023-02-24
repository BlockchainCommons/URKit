import Foundation
import DCBOR

public protocol URDecodable: CBORTaggedDecodable {
    init(ur: UR) throws
}

public extension URDecodable {
    init(ur: UR) throws {
        try ur.checkType(Self.cborTag.name!)
        try self.init(untaggedCBOR: ur.cbor)
    }
    
    init(urString: String) throws {
        try self.init(ur: UR(urString: urString))
    }
}
