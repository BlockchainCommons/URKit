//
//  URTests.swift
//  URKitTests
//
//  Created by Wolf McNally on 7/5/20.
//

import XCTest
@testable import URKit

class URTests: XCTestCase {
    func testSinglePartUR() throws {
        let ur = makeMessageUR(len: 50)
        let encoded = UREncoder.encode(ur)
        //print(encoded)
        let expected = "ur:bytes/hdeymejtswhhylkepmykhhtsytsnoyoyaxaedsuttydmmhhpktpmsrjtgwdpfnsboxgwlbaawzuefywkdplrsrjynbvygabwjldapfcsdwkbrkch"
        XCTAssertEqual(encoded, expected)
        let decoded = try URDecoder.decode(encoded)
        XCTAssertEqual(ur, decoded)
    }

    func testEncode() throws {
        let ur = makeMessageUR(len: 256)
        let encoder = UREncoder(ur, maxFragmentLen: 30)
        let parts = (0 ..< 20).map { _ in encoder.nextPart() }
        //print(parts)
        let expectedParts = [
            "ur:bytes/1-9/ltadascfadaxcywenbpljkhdcahkadaemejtswhhylkepmykhhtsytsnoyoyaxaedsuttydmmhhpktpmsrjtdkgsltgh",
            "ur:bytes/2-9/ltaoascfadaxcywenbpljkhdcagwdpfnsboxgwlbaawzuefywkdplrsrjynbvygabwjldapfcsgmghhkhstlrdcxaefz",
            "ur:bytes/3-9/ltaxascfadaxcywenbpljkhdcahelbknlkuejnbadmssfhfrdpsbiegecpasvssovlgeykssjykklronvsjksopdzool",
            "ur:bytes/4-9/ltaaascfadaxcywenbpljkhdcasotkhemthydawydtaxneurlkosgwcekonertkbrlwmplssjtammdplolsbrdzertas",
            "ur:bytes/5-9/ltahascfadaxcywenbpljkhdcatbbdfmssrkzocwnezmlennjpfzbgmuktrhtejscktelgfpdlrkfyfwdajldejokbwf",
            "ur:bytes/6-9/ltamascfadaxcywenbpljkhdcackjlhkhybssklbwefectpfnbbectrljectpavyrolkzezepkmwidmwoxkilghdsowp",
            "ur:bytes/7-9/ltatascfadaxcywenbpljkhdcavszownjkwtclrtvaynhpahrtoxmwvwatmedibkaegdosftvandiodagdhthtrlnnhy",
            "ur:bytes/8-9/ltayascfadaxcywenbpljkhdcadmsponkkbbhgsolnjntegepmttmoonftnbuoiyrehfrtsabzsttorodklubbuyaetk",
            "ur:bytes/9-9/ltasascfadaxcywenbpljkhdcajskecpmdckihdyhphfotjojtfmlpwmadspaxrkytbztpbauotbgtgtaeaevtgavtny",
            "ur:bytes/10-9/ltbkascfadaxcywenbpljkhdcahkadaemejtswhhylkepmykhhtsytsnoyoyaxaedsuttydmmhhpktpmsrjtwdkiplzs",
            "ur:bytes/11-9/ltbdascfadaxcywenbpljkhdcahelbknlkuejnbadmssfhfrdpsbiegecpasvssovlgeykssjykklronvsjkvetiiapk",
            "ur:bytes/12-9/ltbnascfadaxcywenbpljkhdcarllaluzodmgstospeyiefmwejlwtpedamktksrvlcygmzmmovovllarodtmtbnptrs",
            "ur:bytes/13-9/ltbtascfadaxcywenbpljkhdcamtkgtpknghchchyketwsvwgwfdhpgmgtylctotztpdrpayoschcmhplffziachrfgd",
            "ur:bytes/14-9/ltbaascfadaxcywenbpljkhdcapazmwnvonnvdnsbyleynwtnsjkjndeoldydkbkdslgjkbbkortbelomueekgvstegt",
            "ur:bytes/15-9/ltbsascfadaxcywenbpljkhdcaynmhpddpzoversbdqdfyrehnqzlugmjzmnmtwmrouohtstgsbsahpawkditkckynwt",
            "ur:bytes/16-9/ltbeascfadaxcywenbpljkhdcawygekobamwtlihsnpalpsghenskkiynthdzttsimtojetprsttmukirlrsbtamjtpd",
            "ur:bytes/17-9/ltbyascfadaxcywenbpljkhdcamklgftaxykpewyrtqzhydntpnytyisincxmhtbceaykolduortotiaiaiafhiaoyce",
            "ur:bytes/18-9/ltbgascfadaxcywenbpljkhdcahkadaemejtswhhylkepmykhhtsytsnoyoyaxaedsuttydmmhhpktpmsrjtntwkbkwy",
            "ur:bytes/19-9/ltbwascfadaxcywenbpljkhdcadekicpaajootjzpsdrbalteywllbdsnbinaerkurspbncxgslgftvtsrjtksplcpeo",
            "ur:bytes/20-9/ltbbascfadaxcywenbpljkhdcayapmrleeleaxpasfrtrdkncffwjyjzgyetdmlewtkpktgllepfrltatazcksmhkbot"
        ]
        XCTAssertEqual(parts, expectedParts)
    }

    func testMultipartUR() throws {
        let ur = makeMessageUR(len: 32767)
        let maxFragmentLen = 1000
        let encoder = UREncoder(ur, maxFragmentLen: maxFragmentLen, firstSeqNum: 100)
        let decoder = URDecoder()
        repeat {
            let part = encoder.nextPart()
            decoder.receivePart(part)
            //print(decoder.estimatedPercentComplete)
        } while(decoder.result == nil)
        switch decoder.result! {
        case .success(let decodedUR):
            XCTAssertEqual(ur, decodedUR)
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }
}
