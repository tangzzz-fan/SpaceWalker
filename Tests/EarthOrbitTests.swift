import XCTest
import simd

@testable import SpaceWalker

final class EarthOrbitTests: XCTestCase {
    func testConstantsMatchPublishedValues() {
        XCTAssertEqual(EarthOrbitConstants.earthRadiusKilometers, 6371, accuracy: 1)
        XCTAssertEqual(EarthOrbitConstants.earthMoonDistanceKilometers, 384_400, accuracy: 4000)
        XCTAssertEqual(EarthOrbitConstants.tiangongAltitudeKilometers, 350, accuracy: 10)
        XCTAssertEqual(EarthOrbitConstants.tiangongInclinationDegrees, 42.77, accuracy: 0.01)
        XCTAssertEqual(EarthOrbitConstants.moonRadiusKilometers, 1737.4, accuracy: 1)
    }

    func testDisplayGeometryKeepsRealRatios() {
        let moonRatio = EarthOrbitGeometry.moonDisplayRadius / EarthOrbitGeometry.earthDisplayRadius
        XCTAssertEqual(
            Double(moonRatio),
            EarthOrbitConstants.moonRadiusKilometers / EarthOrbitConstants.earthRadiusKilometers,
            accuracy: 0.001
        )
        let distanceRatio = EarthOrbitGeometry.moonDisplayDistance / EarthOrbitGeometry.earthDisplayRadius
        XCTAssertEqual(
            Double(distanceRatio),
            EarthOrbitConstants.earthMoonDistanceKilometers / EarthOrbitConstants.earthRadiusKilometers,
            accuracy: 0.01
        )
        let orbitRatio = EarthOrbitGeometry.tiangongOrbitDisplayRadius / EarthOrbitGeometry.earthDisplayRadius
        XCTAssertEqual(
            Double(orbitRatio),
            EarthOrbitConstants.tiangongOrbitRadiusKilometers / EarthOrbitConstants.earthRadiusKilometers,
            accuracy: 0.001
        )
    }

    func testBasketballAnalogyIsRecomputable() {
        let expected = 350.0 / (2 * 6371.0) * 0.24 * 1000
        XCTAssertEqual(EarthOrbitConstants.tiangongHeightAboveBasketballMillimeters, expected, accuracy: 0.01)
        XCTAssertEqual(expected, 6.6, accuracy: 0.2)
        XCTAssertTrue(EarthOrbitConstants.analogyText.contains("7 毫米"), EarthOrbitConstants.analogyText)
    }

    func testTiangongOrbitStaysAtConstantAltitude() {
        for step in 0..<100 {
            let position = EarthOrbitGeometry.tiangongPosition(phase: Double(step) / 100)
            XCTAssertEqual(
                simd_length(position),
                EarthOrbitGeometry.tiangongOrbitDisplayRadius,
                accuracy: 0.0001
            )
        }
    }

    func testOrbitInclinationCapsLatitude() {
        for step in 0...240 {
            let track = EarthOrbitGeometry.groundTrack(phase: Double(step) / 240)
            XCTAssertLessThanOrEqual(
                abs(track.latitudeDegrees),
                EarthOrbitConstants.tiangongInclinationDegrees + 0.001
            )
        }
        let maxLat = (0...1000).map {
            abs(EarthOrbitGeometry.groundTrack(phase: Double($0) / 1000).latitudeDegrees)
        }.max() ?? 0
        XCTAssertEqual(maxLat, EarthOrbitConstants.tiangongInclinationDegrees, accuracy: 0.05)
    }

    func testGroundTrackIsContinuousWithoutFoldback() {
        var previous = EarthOrbitGeometry.groundTrack(phase: 0)
        for step in 1...480 {
            let current = EarthOrbitGeometry.groundTrack(phase: Double(step) / 480)
            let dLat = abs(current.latitudeDegrees - previous.latitudeDegrees)
            var dLon = abs(current.longitudeDegrees - previous.longitudeDegrees)
            if dLon > 180 { dLon = 360 - dLon }
            XCTAssertLessThan(dLat, 2.0, "step \(step)")
            XCTAssertLessThan(dLon, 4.0, "step \(step)")
            previous = current
        }
    }

    func testMoonPositionTracksEphemeris() {
        let jd = 2_461_362.5
        let position = EarthOrbitGeometry.moonPosition(julianDay: jd)
        XCTAssertEqual(simd_length(position), EarthOrbitGeometry.moonDisplayDistance, accuracy: 0.001)
        let next = EarthOrbitGeometry.moonPosition(julianDay: jd + 7)
        XCTAssertGreaterThan(simd_distance(position, next), 10, "月球 7 天应移动约四分之一圈")
    }

    func testSunDirectionIsUnitAndMatchesSkyConvention() throws {
        let jd = 2_461_362.5
        let sun = EarthOrbitGeometry.sunDirection(julianDay: jd)
        XCTAssertEqual(simd_length(sun), 1, accuracy: 0.0001)
        let coordinate = try XCTUnwrap(Ephemeris.equatorial(of: .sun, julianDay: jd))
        let expected = StarField.direction(
            rightAscensionHours: coordinate.raHours,
            declinationDegrees: coordinate.decDegrees
        )
        XCTAssertEqual(simd_dot(sun, expected), 1, accuracy: 0.0001)
    }

    func testCameraTransitionWithinBudget() {
        XCTAssertGreaterThan(EarthOrbitCameraStop.transitionDuration, 0)
        XCTAssertLessThanOrEqual(EarthOrbitCameraStop.transitionDuration, 0.45)
    }

    func testCameraStopsStayInRigLimits() {
        for stop in [EarthOrbitCameraStop.overview, .orbitClose] {
            XCTAssertTrue(OrbitRig.distanceRange.contains(stop.rig.distance))
            XCTAssertTrue(OrbitRig.pitchRange.contains(stop.rig.pitch))
        }
        XCTAssertGreaterThan(
            EarthOrbitCameraStop.overview.rig.distance,
            EarthOrbitCameraStop.orbitClose.rig.distance
        )
    }

    func testRulerRangeCoversLayerObjects() {
        let range = ScaleLevel.earthOrbit.rulerRangeMeters
        XCTAssertTrue(range.contains(EarthOrbitConstants.tiangongAltitudeKilometers * 1000))
        XCTAssertTrue(range.contains(EarthOrbitConstants.earthMoonDistanceKilometers * 1000))
    }
}