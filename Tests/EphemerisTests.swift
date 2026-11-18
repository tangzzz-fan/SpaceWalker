import XCTest

@testable import SpaceWalker

final class EphemerisTests: XCTestCase {
    private struct Fixture: Decodable {
        struct Entry: Decodable {
            var body: String
            var date: String
            var julianDay: Double
            var raDegrees: Double
            var decDegrees: Double
        }
        var source: String
        var queryParams: String
        var entries: [Entry]
    }

    private func fixture() throws -> Fixture {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "horizons-geocentric", withExtension: "json"),
            "Horizons fixture 缺失"
        )
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    private func separationArcminutes(
        _ computed: EquatorialCoordinate, raDegrees: Double, decDegrees: Double
    ) -> Double {
        var dra = (computed.raDegrees - raDegrees + 540).truncatingRemainder(dividingBy: 360) - 180
        dra *= cos(decDegrees * .pi / 180)
        let ddec = computed.decDegrees - decDegrees
        return (dra * dra + ddec * ddec).squareRoot() * 60
    }

    func testFixtureCoversNineBodiesSixEpochs() throws {
        let f = try fixture()
        XCTAssertEqual(f.entries.count, 54)
        XCTAssertEqual(Set(f.entries.map(\.body)).count, 9)
        XCTAssertEqual(Set(f.entries.map(\.date)).count, 6)
        XCTAssertTrue(f.queryParams.contains("500@399"))
        XCTAssertTrue(f.entries.contains { $0.date == "2026-11-18" })
    }

    func testPlanetsAndSunWithinTenArcminutes() throws {
        for entry in try fixture().entries where entry.body != "moon" {
            let body = try XCTUnwrap(EphemerisBody(rawValue: entry.body))
            let computed = try XCTUnwrap(
                Ephemeris.equatorial(of: body, julianDay: entry.julianDay), entry.body
            )
            let sep = separationArcminutes(
                computed, raDegrees: entry.raDegrees, decDegrees: entry.decDegrees
            )
            XCTAssertLessThanOrEqual(sep, 10, "\(entry.body) \(entry.date): \(sep)′")
        }
    }

    func testMoonWithinTwentyArcminutes() throws {
        for entry in try fixture().entries where entry.body == "moon" {
            let computed = try XCTUnwrap(
                Ephemeris.equatorial(of: .moon, julianDay: entry.julianDay)
            )
            let sep = separationArcminutes(
                computed, raDegrees: entry.raDegrees, decDegrees: entry.decDegrees
            )
            XCTAssertLessThanOrEqual(sep, 20, "moon \(entry.date): \(sep)′")
        }
    }

    func testEarthHasNoGeocentricPosition() {
        XCTAssertNil(Ephemeris.equatorial(of: .earth, julianDay: 2_461_362.5))
        XCTAssertNil(Ephemeris.distanceAU(of: .earth, julianDay: 2_461_362.5))
    }

    func testMeeusExample47a() {
        let jd = 2_448_724.5
        let (lon, lat) = Moon.eclipticLongitudeLatitude(julianDay: jd)
        XCTAssertEqual(lon, 133.162655, accuracy: 0.01)
        XCTAssertEqual(lat, -3.229126, accuracy: 0.01)
        XCTAssertEqual(Moon.distanceKilometers(julianDay: jd), 368409.7, accuracy: 100)
    }

    func testSunDistanceIsOneAU() throws {
        let dist = try XCTUnwrap(Ephemeris.distanceAU(of: .sun, julianDay: 2_461_362.5))
        XCTAssertEqual(dist, 1.0, accuracy: 0.02)
    }

    func testMoonDistanceIsPlausible() {
        for jd in [2_451_545.0, 2_461_362.5, 2_469_807.5] {
            let km = Moon.distanceKilometers(julianDay: jd)
            XCTAssertGreaterThan(km, 350_000)
            XCTAssertLessThan(km, 410_000)
        }
    }

    func testLightTravelTime() {
        XCTAssertEqual(Ephemeris.lightTravelSeconds(distanceAU: 1), 499.0, accuracy: 0.1)
    }

    func testMoonPhaseBoundsAndNewMoon() {
        let jd = 2_461_362.5
        let phase = Ephemeris.moonPhase(julianDay: jd)
        XCTAssertGreaterThanOrEqual(phase.illuminatedFraction, 0)
        XCTAssertLessThanOrEqual(phase.illuminatedFraction, 1)
        XCTAssertGreaterThanOrEqual(phase.ageDays, 0)
        XCTAssertLessThan(phase.ageDays, 29.54)

        var newMoonJD = jd
        var best = 1.0
        for offset in stride(from: 0.0, through: 30.0, by: 0.25) {
            let p = Ephemeris.moonPhase(julianDay: jd + offset)
            if p.illuminatedFraction < best {
                best = p.illuminatedFraction
                newMoonJD = jd + offset
            }
        }
        XCTAssertLessThan(best, 0.02, "一个朔望月内应出现近朔（jd \(newMoonJD)）")
    }

    func testPhaseWaxingFlipsAcrossFullMoon() {
        let jd = 2_461_362.5
        var sawWaxing = false
        var sawWaning = false
        for offset in stride(from: 0.0, through: 30.0, by: 1.0) {
            let p = Ephemeris.moonPhase(julianDay: jd + offset)
            sawWaxing = sawWaxing || p.waxing
            sawWaning = sawWaning || !p.waxing
        }
        XCTAssertTrue(sawWaxing && sawWaning)
    }

    func testJulianDayMatchesAstronomy() {
        let date = Date(timeIntervalSince1970: 1_763_424_000)
        XCTAssertEqual(
            Ephemeris.julianDay(utc: date), Astronomy.julianDay(date), accuracy: 1e-9
        )
    }

    func testCoordinateIsNormalized() throws {
        for body in EphemerisBody.allCases where body != .earth {
            let c = try XCTUnwrap(Ephemeris.equatorial(of: body, julianDay: 2_461_362.5))
            XCTAssertGreaterThanOrEqual(c.raHours, 0)
            XCTAssertLessThan(c.raHours, 24)
            XCTAssertGreaterThanOrEqual(c.decDegrees, -90)
            XCTAssertLessThanOrEqual(c.decDegrees, 90)
        }
    }
}