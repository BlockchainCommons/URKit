import Foundation
import DCBOR

public protocol UREncodable: CBORTaggedEncodable {
    var ur: UR { get }
}

public extension UREncodable {
    var ur: UR {
        try! UR(type: Self.cborTag.name!, untaggedCBOR: untaggedCBOR)
    }
}
