import Foundation
import XCTest
import WolfBase
import URKit

class CBORDiagnosticTests: XCTestCase {
    func testSimpleValues() {
        XCTAssertEqual(CBOR(nil).diagnostic, "null")
        XCTAssertEqual(CBOR(true).diagnostic, "true")
        XCTAssertEqual(CBOR(false).diagnostic, "false")
    }
    
    func testUnsignedIntegers() {
        XCTAssertEqual(CBOR(0).diagnostic, "0")
        XCTAssertEqual(CBOR(23).diagnostic, "23")
        XCTAssertEqual(CBOR(65546).diagnostic, "65546")
        XCTAssertEqual(CBOR(4294967306).diagnostic, "4294967306")
    }
    
    func testNegativeIntegers() {
        XCTAssertEqual(CBOR(-1).diagnostic, "-1")
        XCTAssertEqual(CBOR(-1000).diagnostic, "-1000")
        XCTAssertEqual(CBOR(-1000000).diagnostic, "-1000000")
    }
    
    func testFloat() {
        XCTAssertEqual(CBOR.float(3.14).diagnostic, "3.14")
        XCTAssertEqual(CBOR.float(-3.14).diagnostic, "-3.14")
        XCTAssertEqual(CBOR.double(3.14).diagnostic, "3.14")
        XCTAssertEqual(CBOR.double(-3.14).diagnostic, "-3.14")
    }
    
    func testString() {
        XCTAssertEqual(CBOR("Test").diagnostic, #""Test""#)
    }
    
    func testByteString() {
        XCTAssertEqual(CBOR.data(‡"00112233aabbccdd").diagnostic, "h'00112233aabbccdd'")
    }
    
    func testArray() {
        XCTAssertEqual(CBOR.array([1, 2, 3]).diagnostic, "[1, 2, 3]")
        XCTAssertEqual(CBOR.array(["A", "B", "C"]).diagnostic, #"["A", "B", "C"]"#)
    }
    
    func testMap() {
        let s = CBOR.map([1: 2, 3: 4]).diagnostic
        XCTAssert(s == "{1: 2, 3: 4}" || s == "{3: 4, 1: 2}")
    }
    
    func testOrderedMap() {
        let s = CBOR.orderedMap([
            .init(key: CBOR(1), value: CBOR(2)),
            .init(key: CBOR(3), value: CBOR(4))
        ]).diagnostic
        XCTAssertEqual(s, "{1: 2, 3: 4}")
    }
    
    func testTagged() {
        XCTAssertEqual(CBOR.tagged(100, CBOR(true)).diagnostic, "100(true)")
    }
    
    func testDate() {
        XCTAssertEqual(CBOR.date(Date(timeIntervalSince1970: -100)).diagnostic, "1(-100)")
        XCTAssertEqual(CBOR.date(Date(timeIntervalSince1970: 1000)).diagnostic, "1(1000)")
        XCTAssertEqual(CBOR.date(Date(timeIntervalSince1970: 1647887071.573193)).diagnostic, "1(1647887071.573193)")
        XCTAssertEqual(CBOR.date(Date(timeIntervalSince1970: 2.9802322387695312e-06)).diagnostic, "1(2.9802322387695312e-06)")
    }
    
    func testStructure() {
        let encodedCBOR = ‡"d83183015829536f6d65206d7973746572696573206172656e2774206d65616e7420746f20626520736f6c7665642e82d902c3820158402b9238e19eafbc154b49ec89edd4e0fb1368e97332c6913b4beb637d1875824f3e43bd7fb0c41fb574f08ce00247413d3ce2d9466e0ccfa4a89b92504982710ad902c3820158400f9c7af36804ffe5313c00115e5a31aa56814abaa77ff301da53d48613496e9c51a98b36d55f6fb5634fdb0123910cfa4904f1c60523df41013dc3749b377900"
        let expectedDiagnostic = #"49([1, h'536f6d65206d7973746572696573206172656e2774206d65616e7420746f20626520736f6c7665642e', [707([1, h'2b9238e19eafbc154b49ec89edd4e0fb1368e97332c6913b4beb637d1875824f3e43bd7fb0c41fb574f08ce00247413d3ce2d9466e0ccfa4a89b92504982710a']), 707([1, h'0f9c7af36804ffe5313c00115e5a31aa56814abaa77ff301da53d48613496e9c51a98b36d55f6fb5634fdb0123910cfa4904f1c60523df41013dc3749b377900'])]])"#
        let cbor = try! CBOR(encodedCBOR, orderedKeys: true)
        XCTAssertEqual(cbor.diagnostic, expectedDiagnostic)
    }
    
    func testStructure2() {
        let encodedCBOR = ‡"d9012ca4015059f2293a5bce7d4de59e71b4207ac5d202c11a6035970003754461726b20507572706c652041717561204c6f766504787b4c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e73656374657475722061646970697363696e6720656c69742c2073656420646f20656975736d6f642074656d706f7220696e6369646964756e74207574206c61626f726520657420646f6c6f7265206d61676e6120616c697175612e"
        let expectedDiagnostic = #"300({1: h'59f2293a5bce7d4de59e71b4207ac5d2', 2: 1(1614124800), 3: "Dark Purple Aqua Love", 4: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."})"#
        let cbor = try! CBOR(encodedCBOR, orderedKeys: true)
        XCTAssertEqual(cbor.diagnostic, expectedDiagnostic)
    }
}
