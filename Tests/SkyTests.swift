import XCTest
import simd
@testable import SpaceWalker

final class StarCatalogTests: XCTestCase {
    func testDirectionIsUnitLength() {
        let vector = StarField.direction(rightAscensionHours: 7.5, declinationDegrees: 23.4)
        XCTAssertEqual(simd_length(vector), 1, accuracy: 0.0001)
    }

    func testDirectionCardinalPoints() {
        let north = StarField.direction(rightAscensionHours: 0, declinationDegrees: 90)
        XCTAssertEqual(north.y, 1, accuracy: 0.0001)

        let vernal = StarField.direction(rightAscensionHours: 0, declinationDegrees: 0)
        XCTAssertEqual(vernal.x, 1, accuracy: 0.0001)
        XCTAssertEqual(vernal.z, 0, accuracy: 0.0001)

        let sixHours = StarField.direction(rightAscensionHours: 6, declinationDegrees: 0)
        XCTAssertEqual(sixHours.z, -1, accuracy: 0.0001)
    }

    func testDirectionBasisIsRightHanded() {
        let vernal = StarField.direction(rightAscensionHours: 0, declinationDegrees: 0)
        let pole = StarField.direction(rightAscensionHours: 0, declinationDegrees: 90)
        let sixthHour = StarField.direction(rightAscensionHours: 6, declinationDegrees: 0)

        XCTAssertEqual(simd_dot(simd_cross(vernal, pole), sixthHour), -1, accuracy: 0.0001)
    }

    func testPositionSitsOnSphere() {
        let star = Star(
            rightAscensionHours: 12,
            declinationDegrees: -30,
            magnitude: 2,
            colorIndex: 0.3,
            name: "Test",
            constellation: "TST"
        )
        XCTAssertEqual(simd_length(StarField.position(for: star)), StarField.sphereRadius, accuracy: 0.001)
    }

    func testBucketIndexCoversMagnitudeRange() {
        XCTAssertEqual(StarField.bucketIndex(for: -1.5), 0)
        XCTAssertEqual(StarField.bucketIndex(for: 0.4), 1)
        XCTAssertEqual(StarField.bucketIndex(for: 2.5), 3)
        XCTAssertEqual(StarField.bucketIndex(for: 4.4), 5)
        XCTAssertEqual(StarField.bucketIndex(for: 9.9), StarField.bucketEdges.count - 2)
    }

    func testCubeSizeShrinksWithMagnitudeAndIsClamped() {
        let bright = StarField.cubeSize(for: -1.5)
        let faint = StarField.cubeSize(for: 5.5)
        XCTAssertGreaterThan(bright, faint)
        XCTAssertGreaterThanOrEqual(faint, 0.12)
        XCTAssertLessThanOrEqual(bright, 0.62)
    }

    func testBrightnessStaysInReadableRange() {
        XCTAssertEqual(StarField.brightness(for: -2), 1, accuracy: 0.001)
        XCTAssertEqual(StarField.brightness(for: 12), 0.5, accuracy: 0.001)
    }

    func testColorMovesFromCoolToWarm() {
        let cool = StarField.color(forColorIndex: -0.3)
        let warm = StarField.color(forColorIndex: 2.0)
        XCTAssertGreaterThan(warm.x, cool.x)
        XCTAssertLessThan(warm.z, cool.z)
    }

    func testDecodeAcceptsCatalogPayload() throws {
        let json = """
        {"source":"test","license":"CC","stars":[
        {"ra":6.752,"dec":-16.716,"mag":-1.46,"ci":0.009,"name":"Sirius","con":"CMa"}]}
        """
        let catalog = try StarCatalog.decode(Data(json.utf8))
        XCTAssertEqual(catalog.stars.count, 1)
        XCTAssertEqual(catalog.stars.first?.name, "Sirius")
        XCTAssertTrue(catalog.stars.first?.isNamed == true)
    }
}

final class StarFieldBuilderTests: XCTestCase {
    func testSphereVertexAndIndexCounts() {
        let data = StarFieldBuilder.sphere(center: .zero, radius: 1, segments: 6, rings: 4)
        XCTAssertEqual(data.positions.count, 5 * 7)
        XCTAssertEqual(data.indices.count, 4 * 6 * 6)
        XCTAssertEqual(data.normals.count, data.positions.count)
    }

    func testSpherePointsLieOnRadius() {
        let data = StarFieldBuilder.sphere(center: SIMD3(3, 0, 0), radius: 0.5, segments: 6, rings: 4)
        for position in data.positions {
            XCTAssertEqual(simd_length(position - SIMD3(3, 0, 0)), 0.5, accuracy: 0.0005)
        }
    }

    func testMergeOffsetsIndices() {
        let a = StarFieldBuilder.cube(center: .zero, size: 1)
        let merged = StarFieldBuilder.merge([a, a])
        XCTAssertEqual(merged.positions.count, a.positions.count * 2)
        let vertexCount = UInt32(a.positions.count)
        XCTAssertTrue(merged.indices.allSatisfy { $0 < vertexCount * 2 })
        XCTAssertTrue(merged.indices.dropFirst(a.indices.count).allSatisfy { $0 >= vertexCount })
    }

    func testBucketsKeepEveryStar() {
        let stars = [
            Star(rightAscensionHours: 0, declinationDegrees: 0, magnitude: -1, colorIndex: 0, name: "A", constellation: ""),
            Star(rightAscensionHours: 1, declinationDegrees: 0, magnitude: 3.5, colorIndex: 1, name: "", constellation: ""),
        ]
        let buckets = StarFieldBuilder.buckets(for: stars)
        XCTAssertEqual(buckets.count, StarField.bucketEdges.count - 1)
        XCTAssertEqual(buckets.flatMap { $0 }.count, stars.count)
    }
}

final class SkyRigTests: XCTestCase {
    func testDragClampsPitchAndChangesYaw() {
        var rig = SkyRig()
        rig.drag(deltaX: 100, deltaY: 10_000)
        XCTAssertEqual(rig.pitch, SkyRig.pitchRange.lowerBound, accuracy: 0.0001)
        XCTAssertNotEqual(rig.yaw, 0)
    }

    func testDragDownLiftsView() {
        var rig = SkyRig()
        rig.drag(deltaX: 0, deltaY: 120)
        let centered = rig.orientation.inverse.act(SIMD3<Float>(0, 0, -1))
        XCTAssertGreaterThan(centered.y, 0)
    }

    func testOrientationIsUnitQuaternion() {
        var rig = SkyRig()
        rig.drag(deltaX: 40, deltaY: 20)
        XCTAssertEqual(simd_length(rig.orientation.vector), 1, accuracy: 0.0005)
    }
}

final class AttitudeMathTests: XCTestCase {
    func testFlatDeviceLooksAtNadir() {
        let solution = AttitudeMath.solve(attitude: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), gravity: SIMD3(0, 0, -1))
        XCTAssertEqual(solution.convention, .deviceToReference)
        XCTAssertEqual(solution.deviceForward.y, -1, accuracy: 0.001)
        XCTAssertEqual(solution.sceneOrientation.act(solution.deviceForward).z, -1, accuracy: 0.001)
    }

    func testUprightDeviceKeepsForwardAtScreenCenter() {
        let attitude = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        let solution = AttitudeMath.solve(attitude: attitude, gravity: SIMD3(0, -1, 0))
        XCTAssertEqual(solution.convention, .deviceToReference)
        XCTAssertEqual(solution.deviceForward.z, -1, accuracy: 0.001)
        XCTAssertEqual(solution.deviceForward.y, 0, accuracy: 0.001)
    }

    func testSceneOrientationInvertsDeviceRotation() {
        let world = simd_quatf(angle: -0.5, axis: SIMD3(0, 1, 0)) * simd_quatf(angle: 0.3, axis: SIMD3(1, 0, 0))
        let attitude = AttitudeMath.referenceToWorld.inverse * world
        let gravity = world.inverse.act(SIMD3<Float>(0, -1, 0))
        let solution = AttitudeMath.solve(attitude: attitude, gravity: gravity)

        XCTAssertEqual(solution.convention, .deviceToReference)
        XCTAssertEqual(
            simd_length(solution.sceneOrientation.act(solution.deviceForward) - SIMD3<Float>(0, 0, -1)),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(abs(simd_dot(solution.sceneOrientation.vector, world.inverse.vector)), 1, accuracy: 0.001)
    }

    func testTurnRightMovesStarsLeft() {
        let world = simd_quatf(angle: -.pi / 6, axis: SIMD3(0, 1, 0))
        let attitude = AttitudeMath.referenceToWorld.inverse * world
        let gravity = world.inverse.act(SIMD3<Float>(0, -1, 0))
        let solution = AttitudeMath.solve(attitude: attitude, gravity: gravity)
        let centeredStar = solution.sceneOrientation.act(SIMD3<Float>(0, 0, -1))

        XCTAssertLessThan(centeredStar.x, 0)
    }

    func testSolveAcceptsEitherQuaternionConvention() {
        let world = simd_quatf(angle: 0.8, axis: SIMD3(0, 1, 0))
        let attitude = AttitudeMath.referenceToWorld.inverse * world
        let gravity = world.inverse.act(SIMD3<Float>(0, -1, 0))

        let direct = AttitudeMath.solve(attitude: attitude, gravity: gravity)
        let inverted = AttitudeMath.solve(attitude: attitude.inverse, gravity: gravity)

        XCTAssertEqual(direct.convention, .deviceToReference)
        XCTAssertEqual(inverted.convention, .referenceToDevice)
        XCTAssertEqual(abs(simd_dot(direct.sceneOrientation.vector, inverted.sceneOrientation.vector)), 1, accuracy: 0.001)
    }
}

final class SkyPickerTests: XCTestCase {
    private func star(_ ra: Double, _ dec: Double, _ mag: Double, _ name: String) -> Star {
        Star(rightAscensionHours: ra, declinationDegrees: dec, magnitude: mag, colorIndex: 0, name: name, constellation: "")
    }

    func testNearestKeepsOnlyPrefilterWindow() {
        let sirius = star(6.753, -16.72, -1.44, "Sirius")
        let far = star(6.753, -11.72, 1.0, "FiveDegreesNorth")
        let near = star(6.753, -15.72, 3.0, "OneDegreeNorth")

        let result = SkyPicker.nearest(to: SkyPicker.direction(for: sirius), in: [sirius, far, near])

        XCTAssertEqual(result.first, sirius)
        XCTAssertTrue(result.contains(near))
        XCTAssertFalse(result.contains(far))
    }

    func testNearestSkipsUnnamedAndFaintStars() {
        let sirius = star(6.753, -16.72, -1.44, "Sirius")
        let unnamed = star(6.753, -16.72, 0.5, "")
        let faint = star(6.753, -16.72, 5.2, "Faint")

        let result = SkyPicker.nearest(to: SkyPicker.direction(for: sirius), in: [unnamed, faint, sirius])

        XCTAssertEqual(result, [sirius])
    }

    func testNearestPrefersBrighterAtSamePosition() {
        let bright = star(14.660, -60.83, -0.01, "Rigil Kentaurus")
        let faint = star(14.660, -60.84, 1.35, "Toliman")

        let result = SkyPicker.nearest(to: SkyPicker.direction(for: bright), in: [faint, bright])

        XCTAssertEqual(result.first, bright)
    }

    func testNearestRejectsZeroDirection() {
        XCTAssertTrue(SkyPicker.nearest(to: .zero, in: [star(0, 0, 1, "A")]).isEmpty)
    }
}

final class DwellSelectorTests: XCTestCase {
    private let sirius = Star(rightAscensionHours: 6.753, declinationDegrees: -16.72, magnitude: -1.44, colorIndex: 0, name: "Sirius", constellation: "CMa")
    private let vega = Star(rightAscensionHours: 18.616, declinationDegrees: 38.78, magnitude: 0.03, colorIndex: 0, name: "Vega", constellation: "Lyr")

    func testCommitAfterThresholdOnly() {
        var selector = DwellSelector()
        var commits: [Star] = []

        for step in 0...5 {
            if let hit = selector.update(candidate: sirius, at: Double(step) * 0.1) {
                commits.append(hit)
            }
        }
        XCTAssertTrue(commits.isEmpty)
        XCTAssertEqual(selector.progress, 5.0 / 6.0, accuracy: 0.001)

        XCTAssertEqual(selector.update(candidate: sirius, at: 0.6), sirius)
    }

    func testSwitchTargetRestartsTimer() {
        var selector = DwellSelector()
        _ = selector.update(candidate: sirius, at: 0)
        _ = selector.update(candidate: sirius, at: 0.3)
        XCTAssertGreaterThan(selector.progress, 0)

        _ = selector.update(candidate: vega, at: 0.4)
        XCTAssertEqual(selector.progress, 0, accuracy: 0.0001)
        XCTAssertNil(selector.update(candidate: vega, at: 0.5))
    }

    func testLosingTargetDecaysProgress() {
        var selector = DwellSelector()
        _ = selector.update(candidate: sirius, at: 0)
        _ = selector.update(candidate: sirius, at: 0.3)
        let peak = selector.progress

        _ = selector.update(candidate: nil, at: 0.4)
        XCTAssertLessThan(selector.progress, peak)
        _ = selector.update(candidate: nil, at: 0.5)
        _ = selector.update(candidate: nil, at: 0.6)
        XCTAssertEqual(selector.progress, 0, accuracy: 0.0001)
    }

    func testCommitRequiresLeavingTargetBeforeRefire() {
        var selector = DwellSelector()
        for step in 0...6 {
            _ = selector.update(candidate: sirius, at: Double(step) * 0.1)
        }
        XCTAssertNil(selector.update(candidate: sirius, at: 0.7))

        for step in 8...11 {
            _ = selector.update(candidate: nil, at: Double(step) * 0.1)
        }
        XCTAssertEqual(selector.progress, 0, accuracy: 0.0001)

        var refire: Star?
        for step in 12...18 {
            refire = selector.update(candidate: sirius, at: Double(step) * 0.1) ?? refire
        }
        XCTAssertEqual(refire, sirius)
    }

    func testBriefLossDoesNotRearm() {
        var selector = DwellSelector()
        for step in 0...6 {
            _ = selector.update(candidate: sirius, at: Double(step) * 0.1)
        }

        _ = selector.update(candidate: nil, at: 0.7)
        XCTAssertNil(selector.update(candidate: sirius, at: 0.8))
        XCTAssertNil(selector.update(candidate: sirius, at: 0.9))

        var refire: Star?
        for step in 10...16 {
            refire = selector.update(candidate: nil, at: Double(step) * 0.1) ?? refire
        }
        XCTAssertNil(refire)

        for step in 17...23 {
            refire = selector.update(candidate: sirius, at: Double(step) * 0.1) ?? refire
        }
        XCTAssertEqual(refire, sirius)
    }

    func testLongStallDoesNotJumpProgress() {
        var selector = DwellSelector()
        _ = selector.update(candidate: sirius, at: 0)
        _ = selector.update(candidate: sirius, at: 0.9)
        XCTAssertEqual(selector.progress, DwellSelector.maximumStep / DwellSelector.required, accuracy: 0.0001)
    }
}

final class AstronomyTests: XCTestCase {
    private let j2000Noon = Date(timeIntervalSince1970: 946_728_000)

    func testJulianDayAtJ2000Epoch() {
        XCTAssertEqual(Astronomy.julianDay(j2000Noon), 2451545.0, accuracy: 0.0001)
    }

    func testGreenwichSiderealAtJ2000Epoch() {
        let degrees = Astronomy.greenwichSiderealDegrees(julianDay: 2451545.0)
        XCTAssertEqual(degrees, 280.46061837, accuracy: 0.0001)
    }

    func testLocalSiderealShiftsWithLongitude() {
        let jd = Astronomy.julianDay(j2000Noon)
        let greenwich = Astronomy.localSiderealDegrees(julianDay: jd, longitude: 0)
        let east = Astronomy.localSiderealDegrees(julianDay: jd, longitude: 116.4)
        XCTAssertEqual(Astronomy.normalized(east - greenwich), 116.4, accuracy: 0.001)
    }

    func testLocalSiderealAdvancesWithTime() {
        let jd = Astronomy.julianDay(j2000Noon)
        let later = Astronomy.localSiderealDegrees(julianDay: jd + 1.0 / 24, longitude: 116.4)
        let now = Astronomy.localSiderealDegrees(julianDay: jd, longitude: 116.4)
        XCTAssertEqual(Astronomy.normalized(later - now), 15.041, accuracy: 0.01)
    }

    func testPolarisAltitudeMatchesLatitude() {
        let jd = Astronomy.julianDay(j2000Noon)
        for latitude in [0.0, 23.5, 39.9, 60.0] {
            let sidereal = Astronomy.localSiderealDegrees(julianDay: jd, longitude: 116.4)
            let result = Astronomy.horizontal(
                rightAscensionHours: 2.53,
                declinationDegrees: Astronomy.polarisDeclination,
                siderealDegrees: sidereal,
                latitude: latitude
            )
            XCTAssertEqual(result.altitude, latitude, accuracy: 1.0, "纬度 \(latitude)")
        }
    }

    func testVernalEquinoxAtZenithAtEquator() {
        let result = Astronomy.horizontal(
            rightAscensionHours: 0,
            declinationDegrees: 0,
            siderealDegrees: 0,
            latitude: 0
        )
        XCTAssertEqual(result.altitude, 90, accuracy: 0.001)
    }

    func testEquatorialToHorizontalIsProperRotation() {
        let rotation = Astronomy.equatorialToHorizontalRotation(siderealDegrees: 137.5, latitude: 39.9)
        let matrix = simd_float3x3(rotation)
        XCTAssertEqual(simd_determinant(matrix), 1, accuracy: 0.001)

        let identity = matrix * matrix.transpose
        for column in 0..<3 {
            for row in 0..<3 {
                let expected: Float = column == row ? 1 : 0
                XCTAssertEqual(identity[column][row], expected, accuracy: 0.001)
            }
        }
    }

    func testRotationMatchesDirectHorizontalForManyStars() {
        let latitude = 39.9
        let sidereal = 137.5
        let rotation = Astronomy.equatorialToHorizontalRotation(siderealDegrees: sidereal, latitude: latitude)
        let stars: [(Double, Double)] = [(6.753, -16.72), (18.616, 38.78), (2.53, 89.26), (0, 0), (12, -60)]

        for (ra, dec) in stars {
            let horizontal = Astronomy.horizontal(
                rightAscensionHours: ra,
                declinationDegrees: dec,
                siderealDegrees: sidereal,
                latitude: latitude
            )
            let expected = Astronomy.worldDirection(altitude: horizontal.altitude, azimuth: horizontal.azimuth)
            let actual = rotation.act(StarField.direction(rightAscensionHours: ra, declinationDegrees: dec))
            XCTAssertEqual(simd_length(actual - expected), 0, accuracy: 0.001, "RA \(ra) Dec \(dec)")
        }
    }

    func testFieldRotationPutsHeadingStarInFrontOfDevice() {
        let trueAzimuth = 60.0
        let sceneAzimuth = 30.0
        let star = Astronomy.worldDirection(altitude: 10, azimuth: trueAzimuth)
        let rotation = Astronomy.yawRotation(degrees: Astronomy.fieldRotationDegrees(trueHeading: trueAzimuth, sceneAzimuth: sceneAzimuth))
        let placed = rotation.act(star)

        XCTAssertEqual(Astronomy.sceneAzimuth(placed), sceneAzimuth, accuracy: 0.001)
        XCTAssertEqual(Double(placed.y), Double(star.y), accuracy: 0.0001)
    }

    func testSceneAzimuthOfNorthIsZero() {
        XCTAssertEqual(Astronomy.sceneAzimuth(SIMD3(0, 0, -1)), 0, accuracy: 0.0001)
        XCTAssertEqual(Astronomy.sceneAzimuth(SIMD3(1, 0, 0)), 90, accuracy: 0.0001)
        XCTAssertEqual(Astronomy.sceneAzimuth(SIMD3(0, 0, 1)), 180, accuracy: 0.0001)
    }
}

final class AppRouteTests: XCTestCase {
    func testRouteSwitchIsReduced() {
        var state = AppState()
        XCTAssertEqual(state.route, .solarSystem)
        makeAppReducer()(&state, .route(.sky))
        XCTAssertEqual(state.route, .sky)
    }

    func testInitialRouteFromEnvironment() {
        XCTAssertEqual(LaunchMode.initialRoute(environment: [:]), .solarSystem)
        XCTAssertEqual(LaunchMode.initialRoute(environment: ["SPACEWALKER_MODE": "sky"]), .sky)
    }

    func testSkyMotionDefaultsOn() {
        XCTAssertTrue(LaunchMode.skyMotionEnabled(environment: [:]))
        XCTAssertFalse(LaunchMode.skyMotionEnabled(environment: ["SPACEWALKER_SKYMOTION": "0"]))
    }
}
