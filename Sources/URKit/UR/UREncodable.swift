import Foundation
import DCBOR

public protocol UREncodable: TaggedCBOREncodable {
    static var urType: String { get }
    
    var ur: UR { get }
}

public extension UREncodable {
    var ur: UR {
        try! UR(type: Self.urType, untaggedCBOR: untaggedCBOR)
    }
}
