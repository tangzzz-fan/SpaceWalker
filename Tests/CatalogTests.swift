import XCTest

@testable import SpaceWalker

final class CatalogTests: XCTestCase {
    private func catalog() throws -> StarCatalog {
        try XCTUnwrap(StarCatalog.loadFromBundle(.main), "星表资源缺失")
    }

    func testRedlineCountsDoNotDrift() throws {
        let stars = try catalog().stars
        XCTAssertEqual(stars.count, 2996)
        XCTAssertEqual(stars.filter { $0.magnitude <= 4.5 }.count, 925)
        XCTAssertEqual(stars.filter(\.isNamed).count, 464)
    }

    func testOnlyNamedStarsCarryDistance() throws {
        let stars = try catalog().stars
        let withDistance = stars.filter { $0.distanceLightYears != nil }
        XCTAssertEqual(withDistance.count, 460)
        XCTAssertTrue(withDistance.allSatisfy(\.isNamed))
    }

    func testKnownMissingDistancesStayAbsent() throws {
        let stars = try catalog().stars
        let missing = ["Polis", "Babcock's star", "Campbell's Hydrogen Star", "3C 273"]
        for name in missing {
            let star = try XCTUnwrap(stars.first { $0.name == name }, name)
            XCTAssertNil(star.distanceLightYears, "\(name) 不应有占位距离")
        }
    }

    func testDistancesArePhysicallyPlausible() throws {
        let stars = try catalog().stars
        for star in stars {
            guard let dist = star.distanceLightYears else { continue }
            XCTAssertGreaterThan(dist, 0.1, star.name)
            XCTAssertLessThan(dist, 10000, star.name)
        }
        let sirius = try XCTUnwrap(stars.first { $0.name == "Sirius" })
        XCTAssertEqual(try XCTUnwrap(sirius.distanceLightYears), 8.6, accuracy: 0.1)
        let vega = try XCTUnwrap(stars.first { $0.name == "Vega" })
        XCTAssertEqual(try XCTUnwrap(vega.distanceLightYears), 25.04, accuracy: 0.1)
    }

    func testDecodeReadsOptionalDistance() throws {
        let json = """
        {"source":"test","license":"CC","stars":[
        {"ra":6.752,"dec":-16.716,"mag":-1.46,"ci":0.009,"name":"Sirius","con":"CMa","dist":8.6},
        {"ra":5.9,"dec":7.4,"mag":0.45,"ci":1.5,"name":"Betelgeuse","con":"Ori"}]}
        """
        let decoded = try StarCatalog.decode(Data(json.utf8))
        XCTAssertEqual(decoded.stars[0].distanceLightYears, 8.6)
        XCTAssertNil(decoded.stars[1].distanceLightYears)
    }

    func testSourceHeaderMentionsDistanceAndHasNoDuplication() throws {
        let source = try catalog().source
        XCTAssertTrue(source.contains("dist"))
        let bridge = "HIP 编号经 d3-celestial 桥接"
        XCTAssertEqual(
            source.components(separatedBy: bridge).count - 1, 1,
            "source 里的桥接说明只应出现一次"
        )
    }
}