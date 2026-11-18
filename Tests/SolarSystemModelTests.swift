import XCTest
import simd
@testable import SpaceWalker

final class SolarSystemModelTests: XCTestCase {
    func testCatalogHasSunAndEightPlanets() {
        XCTAssertEqual(SolarSystem.bodies.count, 9)
        XCTAssertEqual(SolarSystem.planets.count, 8)
        XCTAssertEqual(SolarSystem.bodies.first?.id, .sun)
    }

    func testOrbitRadiusGrowsWithDistanceFromSun() {
        var previous: Float = 0
        for planet in SolarSystem.planets {
            let radius = SolarLayout.orbitRadius(for: planet)
            XCTAssertGreaterThan(radius, previous, planet.name)
            previous = radius
        }
    }

    func testOrbitCompressionShrinksOuterRatio() {
        let mercury = SolarLayout.orbitRadius(for: SolarSystem.body(.mercury)!)
        let neptune = SolarLayout.orbitRadius(for: SolarSystem.body(.neptune)!)
        let displayed = neptune / mercury
        let real = Float(30.07 / 0.387)
        XCTAssertLessThan(displayed, real / 4, "非线性压缩应显著收窄轨道跨度")
        XCTAssertGreaterThan(displayed, 3, "压缩过度会让外行星挤在一起")
    }

    func testEarthUsesUnitBodyRadius() {
        let earth = SolarSystem.body(.earth)!
        XCTAssertEqual(SolarLayout.bodyRadius(for: earth), SolarLayout.earthDisplayRadius, accuracy: 0.0001)
    }

    func testSunRadiusIsCapped() {
        let sun = SolarSystem.body(.sun)!
        XCTAssertEqual(SolarLayout.bodyRadius(for: sun), SolarLayout.sunDisplayRadiusCap, accuracy: 0.0001)
        XCTAssertGreaterThan(
            SolarLayout.bodyRadius(for: sun),
            SolarLayout.bodyRadius(for: SolarSystem.body(.jupiter)!)
        )
    }

    func testSunSitsAtOrigin() {
        let sun = SolarSystem.body(.sun)!
        XCTAssertEqual(SolarLayout.position(for: sun, julianDay: 2_461_362.5), .zero)
    }

    func testPlanetReturnsNearStartAfterOnePeriod() {
        let mercury = SolarSystem.body(.mercury)!
        let jd = 2_461_362.5
        let start = SolarLayout.position(for: mercury, julianDay: jd)
        let after = SolarLayout.position(for: mercury, julianDay: jd + mercury.orbitalPeriodDays)
        XCTAssertEqual(simd_distance(start, after), 0, accuracy: 0.02)
    }

    func testPositionStaysOnOrbitalPlane() {
        for planet in SolarSystem.planets {
            let position = SolarLayout.position(for: planet, julianDay: 2_461_362.5 + 137)
            XCTAssertEqual(position.y, 0, accuracy: 0.0001)
            XCTAssertEqual(
                simd_length(position),
                SolarLayout.orbitRadius(for: planet),
                accuracy: 0.001
            )
        }
    }

    func testOuterPlanetMovesSlowerThanInner() {
        let jd = 2_461_362.5
        func swept(_ id: BodyID) -> Double {
            var total = 0.0
            var previous = SolarLayout.heliocentricLongitude(body: id, julianDay: jd)!
            for step in 1...365 {
                let current = SolarLayout.heliocentricLongitude(body: id, julianDay: jd + Double(step))!
                var delta = current - previous
                while delta < -.pi { delta += 2 * .pi }
                while delta > .pi { delta -= 2 * .pi }
                total += delta
                previous = current
            }
            return total
        }
        let mercurySwept = swept(.mercury)
        let neptuneSwept = swept(.neptune)
        XCTAssertEqual(mercurySwept, 2 * .pi * 365 / 87.969, accuracy: 0.35)
        XCTAssertGreaterThan(mercurySwept, neptuneSwept * 100)
    }

    func testSaturnIsTheOnlyRingedBody() {
        XCTAssertEqual(SolarSystem.bodies.filter(\.hasRing).map(\.id), [.saturn])
    }

    // MARK: - 084 F4 状态条流速档位（PRD-UI:183「x 天/秒」）

    func testRateStatusTextShowsDaysPerSecond() {
        XCTAssertEqual(SolarSystemState.rateStatusText(1), "1 天/秒")
        XCTAssertEqual(SolarSystemState.rateStatusText(5), "5 天/秒")
        XCTAssertEqual(SolarSystemState.rateStatusText(0.1), "0.1 天/秒")
    }

    func testSpaceStatusLineCombinesPhaseDayAndRate() {
        XCTAssertEqual(
            SolarSystemState.statusDetail(days: 12.9, isPaused: false, rate: 3),
            "运行中 · 第 12 天 · 3 天/秒"
        )
        XCTAssertEqual(
            SolarSystemState.statusDetail(days: 0, isPaused: true, rate: 1),
            "已暂停 · 第 0 天 · 1 天/秒"
        )
    }
}
