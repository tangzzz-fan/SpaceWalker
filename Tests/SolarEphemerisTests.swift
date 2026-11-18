import XCTest
import simd

@testable import SpaceWalker

final class SolarEphemerisTests: XCTestCase {
    private let jd = 2_461_362.5

    func testDisplayLongitudeMatchesEphemerisVector() {
        for planet in SolarSystem.planets {
            let vector = Ephemeris.heliocentricEcliptic(
                of: SolarLayout.ephemerisBody(planet.id), julianDay: jd
            )!
            let expected = atan2(vector.y, vector.x)
            let position = SolarLayout.position(for: planet, julianDay: jd)
            let displayed = atan2(Double(position.z), Double(position.x))
            var delta = abs(displayed - expected)
            if delta > .pi { delta = 2 * .pi - delta }
            XCTAssertLessThan(delta, 1e-5, planet.name)
        }
    }

    func testPositionsChangeWithDate() {
        let earth = SolarSystem.body(.earth)!
        let a = SolarLayout.position(for: earth, julianDay: jd)
        let b = SolarLayout.position(for: earth, julianDay: jd + 90)
        XCTAssertGreaterThan(simd_distance(a, b), 0.5, "地球 90 天应走过约四分之一圈")
    }

    func testEarthLongitudeOnKnownDate() throws {
        let longitude = try XCTUnwrap(
            SolarLayout.heliocentricLongitude(body: .earth, julianDay: 2_451_545.0)
        )
        XCTAssertEqual(longitude * 180 / .pi, 100.0, accuracy: 1.0)
    }

    func testLightTravelTextScalesWithDistance() throws {
        let mercury = try XCTUnwrap(SolarLayout.lightTravelText(
            for: SolarSystem.body(.mercury)!, julianDay: jd
        ))
        XCTAssertTrue(mercury.contains("分钟"), mercury)
        let neptune = try XCTUnwrap(SolarLayout.lightTravelText(
            for: SolarSystem.body(.neptune)!, julianDay: jd
        ))
        XCTAssertTrue(neptune.contains("小时"), neptune)
        XCTAssertNil(SolarLayout.lightTravelText(for: SolarSystem.body(.sun)!, julianDay: jd))
    }

    func testLightTravelUsesSameEphemeris() throws {
        let mars = SolarSystem.body(.mars)!
        let vector = Ephemeris.heliocentricEcliptic(of: .mars, julianDay: jd)!
        let au = (vector.x * vector.x + vector.y * vector.y + vector.z * vector.z).squareRoot()
        let minutes = Ephemeris.lightTravelSeconds(distanceAU: au) / 60
        let text = try XCTUnwrap(SolarLayout.lightTravelText(for: mars, julianDay: jd))
        XCTAssertTrue(text.contains(String(format: "%.1f", minutes)), text)
    }

    func testTimelineExtremeDoesNotJump() {
        var state = SolarSystemState()
        let reducer = SolarSystemReducer.reduce
        reducer(&state, .scrub(days: SolarSystemState.scrubRange.lowerBound))
        let first = SolarLayout.position(for: SolarSystem.body(.earth)!, julianDay: state.julianDay)
        reducer(&state, .scrub(days: SolarSystemState.scrubRange.lowerBound + 1))
        let second = SolarLayout.position(for: SolarSystem.body(.earth)!, julianDay: state.julianDay)
        XCTAssertLessThan(simd_distance(first, second), 0.05, "相邻一天不应跳变")
        reducer(&state, .scrub(days: SolarSystemState.scrubRange.upperBound))
        let last = SolarLayout.position(for: SolarSystem.body(.earth)!, julianDay: state.julianDay)
        XCTAssertGreaterThan(simd_length(last), 0)
    }

    func testNoHardcodedStartPhaseRemains() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/Features/Space/SolarSystemModel.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(source.contains("startPhase"))
    }
}