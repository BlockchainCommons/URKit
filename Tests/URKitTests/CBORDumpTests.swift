import Foundation
import XCTest
import WolfBase
import URKit

class CBORDumpTests: XCTestCase {
    func testDumpUnsigned() {
        XCTAssertEqual(CBOR(1).dump, "01 # unsigned(1)")
        XCTAssertEqual(CBOR(100).dump, "1864 # unsigned(100)")
        XCTAssertEqual(CBOR(1000).dump, "1903e8 # unsigned(1000)")
    }
    
    func testNegative() {
        XCTAssertEqual(CBOR(-1).dump, "20 # negative(-1)")
        XCTAssertEqual(CBOR(-10).dump, "29 # negative(-10)")
        XCTAssertEqual(CBOR(-100).dump, "3863 # negative(-100)")
        XCTAssertEqual(CBOR(-1000).dump, "3903e7 # negative(-1000)")
    }
    
    func testString() {
        let expected = """
        65            # text(5)
           48656c6c6f # "Hello"
        """
        XCTAssertEqual(CBOR("Hello").dump, expected)
    }
    
    func testMisc() {
        XCTAssertEqual(CBOR.simple(10).dump, "ea # simple(10)")
        XCTAssertEqual(CBOR.simple(128).dump, "f880 # simple(128)")
        XCTAssertEqual(CBOR.boolean(false).dump, "f4 # false")
        XCTAssertEqual(CBOR.boolean(true).dump, "f5 # true")
        XCTAssertEqual(CBOR.null.dump, "f6 # null")
        XCTAssertEqual(CBOR.undefined.dump, "f7 # undefined")
    }
    
    func testFloat() {
        XCTAssertEqual(CBOR.float(3.14).dump, "fa 4048f5c3 # 3.14")
        XCTAssertEqual(CBOR.double(3.14).dump, "fb 40091eb851eb851f # 3.14")
    }
    
    func testTagged() {
        let expected = """
        d8 c8            # tag(200)
           65            # text(5)
              48656c6c6f # "Hello"
        """
        XCTAssertEqual(CBOR.tagged(200, "Hello").dump, expected)
        
        let expected2 = """
        c1               # tag(1)   ; epoch-date-time
           65            # text(5)
              48656c6c6f # "Hello"
        """
        XCTAssertEqual(CBOR.tagged(1, "Hello").dump, expected2)
    }
    
    func testArray() {
        let expected = """
        83                # array(3)
           63             # text(3)
              666f6f      # "foo"
           63             # text(3)
              626172      # "bar"
           82             # array(2)
              63          # text(3)
                 62617a   # "baz"
              64          # text(4)
                 71757578 # "quux"
        """
        XCTAssertEqual(CBOR.array(["foo", "bar", ["baz", "quux"]]).dump, expected)
    }
    
    func testEmptyData() {
        let expected = """
        83       # array(3)
           40    # bytes(0)
           40    # bytes(0)
           41    # bytes(1)
              58 # "X"
        """
        XCTAssertEqual(CBOR.array([CBOR.data("".utf8Data), CBOR.data(Data()), CBOR.data("X".utf8Data)]).dump, expected)
    }
    
    func testMap() {
        let cbor = CBOR.map([1: 2, 3: 4])
        let expected1 = """
        a2    # map(2)
           01 # unsigned(1)
           02 # unsigned(2)
           03 # unsigned(3)
           04 # unsigned(4)
        """
        XCTAssertEqual(cbor.dump, expected1)
    }

    func testDate() {
        let d = try! Date("2022-03-21T00:00:00Z", strategy: .iso8601)
        XCTAssertEqual(CBOR.date(d).dump, "c1 1a6237c000 # date(2022-03-21 00:00:00 +0000)")
    }
    
    func testStructure() {
        let encodedCBOR = ‡"d83183015829536f6d65206d7973746572696573206172656e2774206d65616e7420746f20626520736f6c7665642e82d902c3820158402b9238e19eafbc154b49ec89edd4e0fb1368e97332c6913b4beb637d1875824f3e43bd7fb0c41fb574f08ce00247413d3ce2d9466e0ccfa4a89b92504982710ad902c3820158400f9c7af36804ffe5313c00115e5a31aa56814abaa77ff301da53d48613496e9c51a98b36d55f6fb5634fdb0123910cfa4904f1c60523df41013dc3749b377900"
        let expected = """
        d8 31                                    # tag(49)
           83                                    # array(3)
              01                                 # unsigned(1)
              5829                               # bytes(41)
                 536f6d65206d7973746572696573206172656e2774206d65616e7420746f20626520736f6c7665642e # "Some mysteries aren't meant to be solved."
              82                                 # array(2)
                 d9 02c3                         # tag(707)
                    82                           # array(2)
                       01                        # unsigned(1)
                       5840                      # bytes(64)
                          2b9238e19eafbc154b49ec89edd4e0fb1368e97332c6913b4beb637d1875824f3e43bd7fb0c41fb574f08ce00247413d3ce2d9466e0ccfa4a89b92504982710a
                 d9 02c3                         # tag(707)
                    82                           # array(2)
                       01                        # unsigned(1)
                       5840                      # bytes(64)
                          0f9c7af36804ffe5313c00115e5a31aa56814abaa77ff301da53d48613496e9c51a98b36d55f6fb5634fdb0123910cfa4904f1c60523df41013dc3749b377900
        """
        let cbor = try! CBOR(encodedCBOR)
        XCTAssertEqual(cbor.dump, expected)
    }
    
    func testStructure2() {
        let encodedCBOR = ‡"d9012ca4015059f2293a5bce7d4de59e71b4207ac5d202c11a6035970003754461726b20507572706c652041717561204c6f766504787b4c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e73656374657475722061646970697363696e6720656c69742c2073656420646f20656975736d6f642074656d706f7220696e6369646964756e74207574206c61626f726520657420646f6c6f7265206d61676e6120616c697175612e"
        let expected = """
        d9 012c                                  # tag(300)
           a4                                    # map(4)
              01                                 # unsigned(1)
              50                                 # bytes(16)
                 59f2293a5bce7d4de59e71b4207ac5d2
              02                                 # unsigned(2)
              c1 1a60359700                      # date(2021-02-24 00:00:00 +0000)
              03                                 # unsigned(3)
              75                                 # text(21)
                 4461726b20507572706c652041717561204c6f7665 # "Dark Purple Aqua Love"
              04                                 # unsigned(4)
              78 7b                              # text(123)
                 4c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e73656374657475722061646970697363696e6720656c69742c2073656420646f20656975736d6f642074656d706f7220696e6369646964756e74207574206c61626f726520657420646f6c6f7265206d61676e6120616c697175612e # "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
        """
        let cbor = try! CBOR(encodedCBOR)
        XCTAssertEqual(cbor.dump, expected)
    }
}
