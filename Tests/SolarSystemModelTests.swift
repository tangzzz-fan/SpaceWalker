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
        XCTAssertEqual(SolarLayout.position(for: sun, days: 12), .zero)
    }

    func testPlanetReturnsToStartAfterOnePeriod() {
        let mercury = SolarSystem.body(.mercury)!
        let start = SolarLayout.position(for: mercury, days: 0)
        let after = SolarLayout.position(for: mercury, days: mercury.orbitalPeriodDays)
        XCTAssertEqual(simd_distance(start, after), 0, accuracy: 0.001)
    }

    func testPositionStaysOnOrbitalPlane() {
        for planet in SolarSystem.planets {
            let position = SolarLayout.position(for: planet, days: 137)
            XCTAssertEqual(position.y, 0, accuracy: 0.0001)
            XCTAssertEqual(
                simd_length(position),
                SolarLayout.orbitRadius(for: planet),
                accuracy: 0.001
            )
        }
    }

    func testOuterPlanetMovesSlowerThanInner() {
        let mercury = SolarSystem.body(.mercury)!
        let neptune = SolarSystem.body(.neptune)!
        let mercuryTurns = SolarLayout.turns(for: mercury, days: 365) - mercury.startPhase
        let neptuneTurns = SolarLayout.turns(for: neptune, days: 365) - neptune.startPhase
        XCTAssertEqual(mercuryTurns, 365 / mercury.orbitalPeriodDays, accuracy: 0.001)
        XCTAssertGreaterThan(mercuryTurns, neptuneTurns * 100)
    }

    func testSaturnIsTheOnlyRingedBody() {
        XCTAssertEqual(SolarSystem.bodies.filter(\.hasRing).map(\.id), [.saturn])
    }
}
