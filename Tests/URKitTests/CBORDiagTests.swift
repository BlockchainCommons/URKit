import Foundation
import XCTest
import WolfBase
import URKit

class CBORDiagTests: XCTestCase {
    func testSimpleValues() {
        XCTAssertEqual(CBOR(nil).diag, "null")
        XCTAssertEqual(CBOR(true).diag, "true")
        XCTAssertEqual(CBOR(false).diag, "false")
    }
    
    func testUnsignedIntegers() {
        XCTAssertEqual(CBOR(0).diag, "0")
        XCTAssertEqual(CBOR(23).diag, "23")
        XCTAssertEqual(CBOR(65546).diag, "65546")
        XCTAssertEqual(CBOR(1000000000).diag, "1000000000")
    }

    func testNegativeIntegers() {
        XCTAssertEqual(CBOR(-1).diag, "-1")
        XCTAssertEqual(CBOR(-1000).diag, "-1000")
        XCTAssertEqual(CBOR(-1000000).diag, "-1000000")
    }

    func testFloat() {
        XCTAssertEqual(CBOR.float(3.14).diag, "3.14")
        XCTAssertEqual(CBOR.float(-3.14).diag, "-3.14")
        XCTAssertEqual(CBOR.double(3.14).diag, "3.14")
        XCTAssertEqual(CBOR.double(-3.14).diag, "-3.14")
    }

    func testString() {
        XCTAssertEqual(CBOR("Test").diag, #""Test""#)
    }

    func testByteString() {
        XCTAssertEqual(CBOR.data(‡"00112233aabbccdd").diag, "h'00112233aabbccdd'")
    }

    func testArray() {
        let cbor = CBOR.array([[1, 2, 3], ["A", "B", "C"]])
        let expected = """
        [
           [1, 2, 3],
           ["A", "B", "C"]
        ]
        """
        XCTAssertEqual(cbor.diag, expected)
    }

    func testMap() {
        let expected1 = "{1, 2, 3, 4}"
        let expected2 = "{3, 4, 1, 2}"
        let cbor = CBOR.map([1: 2, 3: 4])
        let s = cbor.diag
        XCTAssert(s == expected1 || s == expected2)
    }

    func testTagged() {
        let cbor = CBOR.tagged(100, CBOR(true))
        let expected = "100(true)"
        XCTAssertEqual(cbor.diag, expected)
    }

    func testDate() {
        XCTAssertEqual(CBOR.date(Date(timeIntervalSince1970: -100)).diag, "1(1969-12-31T23:58:20Z)")
        XCTAssertEqual(CBOR.date(Date(timeIntervalSince1970: 1000)).diag, "1(1970-01-01T00:16:40Z)")
        XCTAssertEqual(CBOR.date(Date(timeIntervalSince1970: 1647887071.573193)).diag, "1(2022-03-21T18:24:31Z)")
        XCTAssertEqual(CBOR.date(Date(timeIntervalSince1970: 2.9802322387695312e-06)).diag, "1(1970-01-01T00:00:00Z)")
    }

    func testStructure() {
        let encodedCBOR = ‡"d83183015829536f6d65206d7973746572696573206172656e2774206d65616e7420746f20626520736f6c7665642e82d902c3820158402b9238e19eafbc154b49ec89edd4e0fb1368e97332c6913b4beb637d1875824f3e43bd7fb0c41fb574f08ce00247413d3ce2d9466e0ccfa4a89b92504982710ad902c3820158400f9c7af36804ffe5313c00115e5a31aa56814abaa77ff301da53d48613496e9c51a98b36d55f6fb5634fdb0123910cfa4904f1c60523df41013dc3749b377900"
        let expected = """
        49(
           [
              1,
              h'536f6d65206d7973746572696573206172656e2774206d65616e7420746f20626520736f6c7665642e',
              [
                 707(
                    [
                       1,
                       h'2b9238e19eafbc154b49ec89edd4e0fb1368e97332c6913b4beb637d1875824f3e43bd7fb0c41fb574f08ce00247413d3ce2d9466e0ccfa4a89b92504982710a'
                    ]
                 ),
                 707(
                    [
                       1,
                       h'0f9c7af36804ffe5313c00115e5a31aa56814abaa77ff301da53d48613496e9c51a98b36d55f6fb5634fdb0123910cfa4904f1c60523df41013dc3749b377900'
                    ]
                 )
              ]
           ]
        )
        """
        let cbor = try! CBOR(encodedCBOR)
        XCTAssertEqual(cbor.diag, expected)
    }

    func testStructure2() {
        let encodedCBOR = ‡"d9012ca4015059f2293a5bce7d4de59e71b4207ac5d202c11a6035970003754461726b20507572706c652041717561204c6f766504787b4c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e73656374657475722061646970697363696e6720656c69742c2073656420646f20656975736d6f642074656d706f7220696e6369646964756e74207574206c61626f726520657420646f6c6f7265206d61676e6120616c697175612e"
        let expected = """
        300(
           {
              1,
              h'59f2293a5bce7d4de59e71b4207ac5d2',
              2,
              1(2021-02-24T00:00:00Z),
              3,
              "Dark Purple Aqua Love",
              4,
              "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
           }
        )
        """
        let cbor = try! CBOR(encodedCBOR)
        XCTAssertEqual(cbor.diag, expected)
    }
    
    /// Ensure that key order conforms to:
    /// https://www.rfc-editor.org/rfc/rfc8949.html#section-4.2.1-2.3.2.1
    func testKeyOrder() throws {
        var dict: [CBOR : CBOR] = [:]
        dict[10] = 1
        dict[100] = 2
        dict[-1] = 3
        dict["z"] = 4
        dict["aa"] = 5
        dict[[100]] = 6
        dict[[-1]] = 7
        dict[false] = 8
        let cbor = CBOR.map(dict)
        let expectedDiag = """
        {
           10,
           1,
           100,
           2,
           -1,
           3,
           "z",
           4,
           "aa",
           5,
           [100],
           6,
           [-1],
           7,
           false,
           8
        }
        """
        XCTAssertEqual(cbor.diag, expectedDiag)
        let expectedDump = """
        a8         # map(8)
           0a      # unsigned(10)
           01      # unsigned(1)
           1864    # unsigned(100)
           02      # unsigned(2)
           20      # negative(-1)
           03      # unsigned(3)
           61      # text(1)
              7a   # "z"
           04      # unsigned(4)
           62      # text(2)
              6161 # "aa"
           05      # unsigned(5)
           81      # array(1)
              1864 # unsigned(100)
           06      # unsigned(6)
           81      # array(1)
              20   # negative(-1)
           07      # unsigned(7)
           f4      # false
           08      # unsigned(8)
        """
        XCTAssertEqual(cbor.dump, expectedDump)
        let expectedHex = "a80a011864022003617a046261610581186406812007f408"
        XCTAssertEqual(cbor.hex, expectedHex)
        let decoded = try CBOR(cbor.cborEncode)
        XCTAssertEqual(cbor, decoded)
    }
    
    func testOutOfOrderKeys() {
        let mapWithOutOfOrderKeys = ‡"a8f4080a011864022003617a046261610581186406812007"
        XCTAssertThrowsError(try CBOR(mapWithOutOfOrderKeys)) { error in
            guard let decodingError = error as? CBORDecodingError,
                  decodingError == .keysOutOfOrder else {
                XCTFail()
                return
            }
        }
    }
    
    func testDuplicateKey() {
        let mapWithDuplicateKey = ‡"a90a011864022003617a046261610581186406812007f408f408"
        XCTAssertThrowsError(try CBOR(mapWithDuplicateKey)) { error in
            guard let decodingError = error as? CBORDecodingError,
                  decodingError == .duplicateKey else {
                XCTFail()
                return
            }
        }
    }
}
