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

    func testSelectableAndBackgroundSplitCoversEveryStar() {
        let stars = [
            Star(rightAscensionHours: 5.9, declinationDegrees: 7.4, magnitude: 0.45, colorIndex: 0, name: "Betelgeuse", constellation: "Ori"),
            Star(rightAscensionHours: 5.6, declinationDegrees: -1.2, magnitude: 1.69, colorIndex: 0, name: "", constellation: "Ori"),
            Star(rightAscensionHours: 3.0, declinationDegrees: 10, magnitude: 4.9, colorIndex: 0, name: "TooFaint", constellation: ""),
        ]
        let selectable = StarFieldBuilder.selectableBuckets(for: stars).flatMap { $0 }
        let background = StarFieldBuilder.backgroundStars(for: stars)

        XCTAssertEqual(selectable.count + background.count, stars.count)
        XCTAssertTrue(selectable.allSatisfy(\.isSelectable))
        XCTAssertTrue(background.allSatisfy { !$0.isSelectable })
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
        // 手往下推，视线往上抬；一直推只能顶到上限，不能翻过头顶。
        var rig = SkyRig()
        rig.drag(deltaX: 100, deltaY: 10_000)
        XCTAssertEqual(rig.pitch, SkyRig.pitchRange.upperBound, accuracy: 0.0001)
        XCTAssertNotEqual(rig.yaw, 0)
    }

    func testDragDownLiftsView() {
        var rig = SkyRig()
        rig.drag(deltaX: 0, deltaY: 120)
        let centered = rig.orientation.inverse.act(SIMD3<Float>(0, 0, -1))
        XCTAssertGreaterThan(centered.y, 0)
    }

    func testPanningAtHighPitchDoesNotRollTheSky() {
        // 俯仰 40° 之后再横着转，世界正上方在相机坐标里仍该只有 +Y 分量。
        // 旧的 `Ry·Rx` 把相机朝向当成了星空朝向，实测滚到 58°：
        // 星空没有地平线参照，这个错很难被肉眼发现，只能靠断言钉住。
        var rig = SkyRig(pitch: 0.7)
        rig.drag(deltaX: 320, deltaY: 0)
        let up = rig.orientation.act(SIMD3<Float>(0, 1, 0))
        XCTAssertEqual(up.x, 0, accuracy: 0.001)
        XCTAssertGreaterThan(up.y, 0)
    }

    func testDragRightMovesTheViewLeft() {
        // 手往右推，星空跟着往右走，视线因此向左。
        var rig = SkyRig()
        rig.drag(deltaX: 120, deltaY: 0)
        let centered = rig.orientation.inverse.act(SIMD3<Float>(0, 0, -1))
        XCTAssertLessThan(centered.x, 0)
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

    func testOffsetDegreesMatchesGeometry() {
        XCTAssertEqual(SkyPicker.offsetDegrees(SIMD3(0, 0, -1), SIMD3(0, 0, -1)), 0, accuracy: 0.001)
        XCTAssertEqual(SkyPicker.offsetDegrees(SIMD3(1, 0, 0), SIMD3(0, 0, -1)), 90, accuracy: 0.001)
        XCTAssertEqual(SkyPicker.offsetDegrees(SIMD3(0, 0, 1), SIMD3(0, 0, -1)), 180, accuracy: 0.001)
        XCTAssertEqual(SkyPicker.offsetDegrees(SIMD3(0, 0, -3), SIMD3(0, 0, -1)), 0, accuracy: 0.001)
    }

    func testNearbyFindsBeltNeighbours() throws {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        let alnitak = try XCTUnwrap(catalog.stars.first { $0.name == "Alnitak" })
        let nearby = SkyPicker.nearby(to: alnitak, in: catalog.stars)

        XCTAssertEqual(nearby.first?.name, "Alnilam")
        XCTAssertFalse(nearby.contains { $0.name == "Alnitak" })
        XCTAssertTrue(nearby.allSatisfy(\.isSelectable))
    }

    func testNearbyStopsAtOnePointFiveDegrees() throws {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        let sirius = try XCTUnwrap(catalog.stars.first { $0.name == "Sirius" })
        XCTAssertTrue(SkyPicker.nearby(to: sirius, in: catalog.stars).isEmpty)
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

    func testMovingToNeighbourStartsNewDwell() {
        var selector = DwellSelector()
        for step in 0...6 {
            _ = selector.update(candidate: sirius, at: Double(step) * 0.1)
        }
        XCTAssertNil(selector.update(candidate: vega, at: 0.7))

        var hit: Star?
        for step in 8...13 {
            hit = selector.update(candidate: vega, at: Double(step) * 0.1) ?? hit
        }
        XCTAssertEqual(hit, vega)
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

    func testManualCalibrationPutsStarAtDeviceAzimuth() {
        let starAzimuth = 210.0
        let sceneAzimuth = 40.0
        let offset = Astronomy.fieldRotationDegrees(trueHeading: starAzimuth, sceneAzimuth: sceneAzimuth)
        let placed = Astronomy.yawRotation(degrees: offset).act(
            Astronomy.worldDirection(altitude: 35, azimuth: starAzimuth)
        )

        XCTAssertEqual(Astronomy.sceneAzimuth(placed), sceneAzimuth, accuracy: 0.001)
        XCTAssertEqual(Double(placed.y), sin(35 * .pi / 180), accuracy: 0.001)
    }

    func testSceneAzimuthOfNorthIsZero() {
        XCTAssertEqual(Astronomy.sceneAzimuth(SIMD3(0, 0, -1)), 0, accuracy: 0.0001)
        XCTAssertEqual(Astronomy.sceneAzimuth(SIMD3(1, 0, 0)), 90, accuracy: 0.0001)
        XCTAssertEqual(Astronomy.sceneAzimuth(SIMD3(0, 0, 1)), 180, accuracy: 0.0001)
    }
}

final class ConstellationTests: XCTestCase {
    func testEveryLineReferencesRealCatalogStar() throws {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main), "星表资源缺失")
        // 连线既可能写专名，也可能写 #HIP（2532 颗星没有专名）。
        let keys = Set(catalog.stars.map(\.key).filter { !$0.isEmpty })
        let missing = Constellations.referencedKeys.subtracting(keys)

        XCTAssertTrue(missing.isEmpty, "星座连线引用了星表里不存在的星：\(missing.sorted().prefix(8))")
    }

    func testEveryLineIsWellFormed() {
        for constellation in Constellations.all {
            XCTAssertFalse(constellation.lines.isEmpty, "\(constellation.name) 没有连线")
            for line in constellation.lines {
                XCTAssertNotEqual(line.first, line.second, "\(constellation.name) 存在自连线")
                XCTAssertFalse(line.first.isEmpty)
                XCTAssertFalse(line.second.isEmpty)
            }
        }
    }

    func testAbbreviationsAreUnique() {
        let abbreviations = Constellations.all.map(\.abbreviation)
        XCTAssertEqual(Set(abbreviations).count, abbreviations.count)
    }

    func testSegmentGeometryIsClosedTube() {
        let mesh = StarFieldBuilder.tube(from: SIMD3(0, 0, 0), to: SIMD3(0, 0, -10), radius: 0.05)
        XCTAssertEqual(mesh.positions.count, 16)
        XCTAssertEqual(mesh.normals.count, 16)
        XCTAssertEqual(mesh.indices.count, 48)
        XCTAssertEqual(simd_length(mesh.positions[0] - SIMD3<Float>(0, 0, 0)), 0.05 * sqrt(2), accuracy: 0.0001)
    }

    func testConstellationMeshCoversEverySegment() {
        let segments = [ (SIMD3<Float>(0, 0, -10), SIMD3<Float>(1, 0, -10)), (SIMD3<Float>(1, 0, -10), SIMD3<Float>(1, 1, -10)) ]
        let mesh = StarFieldBuilder.constellation(segments, radius: 0.05)
        XCTAssertEqual(mesh.positions.count, 32)
        XCTAssertEqual(mesh.indices.count, 96)
    }
}

final class StarFinderTests: XCTestCase {
    private let sample: [Star] = [
        Star(rightAscensionHours: 6.75, declinationDegrees: -16.7, magnitude: -1.44, colorIndex: 0.0, name: "Sirius", constellation: "CMa"),
        Star(rightAscensionHours: 5.9, declinationDegrees: 7.4, magnitude: 0.45, colorIndex: 1.5, name: "Betelgeuse", constellation: "Ori"),
        Star(rightAscensionHours: 5.6, declinationDegrees: -1.2, magnitude: 1.69, colorIndex: -0.2, name: "Alnilam", constellation: "Ori"),
        Star(rightAscensionHours: 2.53, declinationDegrees: 89.26, magnitude: 1.97, colorIndex: 0.6, name: "Polaris", constellation: "UMi"),
        Star(rightAscensionHours: 11.06, declinationDegrees: 61.75, magnitude: 1.81, colorIndex: 1.1, name: "Dubhe", constellation: "UMa"),
        Star(rightAscensionHours: 5.6, declinationDegrees: -1.3, magnitude: 3.9, colorIndex: 0.0, name: "", constellation: "Ori"),
    ]

    func testChineseNameSearchFindsSirius() {
        XCTAssertEqual(StarFinder.search(sample, query: "天狼").first?.star.name, "Sirius")
    }

    func testSpokenAliasFindsPolaris() {
        XCTAssertEqual(StarFinder.search(sample, query: "北极星").first?.star.name, "Polaris")
    }

    func testConstellationNicknameListsItsStars() {
        let hits = StarFinder.search(sample, query: "北斗")
        XCTAssertEqual(hits.map(\.star.name), ["Dubhe"])
    }

    func testConstellationNameListsAllSelectableMembers() {
        let hits = StarFinder.search(sample, query: "猎户")
        XCTAssertEqual(hits.map(\.star.name).sorted(), ["Alnilam", "Betelgeuse"])
    }

    func testUnnamedStarIsNeverReturned() {
        for query in ["", "a", "星", "Ori"] {
            XCTAssertFalse(StarFinder.search(sample, query: query).contains { $0.star.name.isEmpty })
        }
    }

    func testChineseNamedStarsAreAllSelectable() {
        let hits = StarFinder.chineseNamed(sample)
        XCTAssertTrue(hits.allSatisfy { $0.star.isSelectable })
        XCTAssertEqual(hits.first?.star.name, "Sirius")
    }

    func testGuideVectorPointsRightAndUp() {
        let right = SkyGuide.vector(to: SIMD3(1, 0, -1))
        XCTAssertEqual(right.yaw, 45, accuracy: 0.01)
        XCTAssertEqual(right.pitch, 0, accuracy: 0.01)
        XCTAssertEqual(right.distance, 45, accuracy: 0.01)

        let up = SkyGuide.vector(to: SIMD3(0, 1, -0.0001))
        XCTAssertEqual(up.pitch, 90, accuracy: 0.01)
        XCTAssertTrue(up.distance > 89)
    }

    func testGuideVectorAlignedAtCenter() {
        let centered = SkyGuide.vector(to: SIMD3(0, 0, -1))
        XCTAssertTrue(centered.isAligned)
        XCTAssertEqual(centered.distance, 0, accuracy: 0.001)
        XCTAssertEqual(centered.instruction, "已对准")
    }

    func testConstellationNameTableCoversCatalog() throws {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        let abbreviations = Set(catalog.stars.map(\.constellation).filter { !$0.isEmpty })
        let missing = abbreviations.subtracting(ConstellationNames.table.keys)
        XCTAssertTrue(missing.isEmpty, "缺少中文星座名：\(missing.sorted())")
    }
}

final class ConstellationInfoTests: XCTestCase {
    private let sample: [Star] = [
        Star(rightAscensionHours: 5.92, declinationDegrees: 7.4, magnitude: 0.45, colorIndex: 1.5, name: "Betelgeuse", constellation: "Ori"),
        Star(rightAscensionHours: 5.24, declinationDegrees: -8.2, magnitude: 0.18, colorIndex: -0.1, name: "Rigel", constellation: "Ori"),
        Star(rightAscensionHours: 16.49, declinationDegrees: -26.4, magnitude: 1.06, colorIndex: 1.8, name: "Antares", constellation: "Sco"),
    ]

    func testEveryDrawnConstellationHasStory() {
        let drawn = Set(Constellations.all.map(\.abbreviation))
        let described = Set(ConstellationInfo.facts.keys)
        let known = Set(ConstellationInfo.latinNames.keys)
        XCTAssertTrue(drawn.subtracting(described).isEmpty, "缺少来头文案：\(drawn.subtracting(described).sorted())")
        XCTAssertTrue(described.subtracting(known).isEmpty, "来头文案里有不存在的星座：\(described.subtracting(known).sorted())")
    }

    func testStoriesAreNonEmpty() {
        for fact in ConstellationInfo.facts.values {
            XCTAssertGreaterThan(fact.westernLore.count, 20, "\(fact.abbreviation) 西方来头过短")
            XCTAssertGreaterThan(fact.chineseLore.count, 15, "\(fact.abbreviation) 中国星官说明过短")
        }
    }

    func testRegionPicksBrightestAndSeason() {
        let region = try? XCTUnwrap(ConstellationInfo.region(for: "Ori", in: sample))
        XCTAssertEqual(region?.brightest?.name, "Rigel")
        XCTAssertEqual(region?.starCount, 2)
        XCTAssertEqual(region?.bestMonth, 1)
        XCTAssertEqual(region?.chineseName, "猎户座")
    }

    func testNearestReturnsConstellationOfPointedRegion() {
        let orion = ConstellationInfo.nearest(
            to: StarField.direction(rightAscensionHours: 5.9, declinationDegrees: 7.4),
            in: sample
        )
        XCTAssertEqual(orion?.abbreviation, "Ori")

        let scorpius = ConstellationInfo.nearest(
            to: StarField.direction(rightAscensionHours: 16.5, declinationDegrees: -26.4),
            in: sample
        )
        XCTAssertEqual(scorpius?.abbreviation, "Sco")
    }

    func testLatinNameTableCoversCatalog() throws {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        let abbreviations = Set(catalog.stars.map(\.constellation).filter { !$0.isEmpty })
        let missing = abbreviations.subtracting(ConstellationInfo.latinNames.keys)
        XCTAssertTrue(missing.isEmpty, "缺少拉丁名：\(missing.sorted())")
    }
}

final class StarDisplayTests: XCTestCase {
    func testBedouSevenStarsMapToBeidou() {
        let expected = ["天枢": 1, "天璇": 2, "天玑": 3, "天权": 4, "玉衡": 5, "开阳": 6, "摇光": 7]
        for (name, index) in expected {
            let asterism = AsterismParser.asterism(for: name)
            XCTAssertEqual(asterism?.name, "北斗", "\(name) 应属北斗")
            XCTAssertEqual(asterism?.index, index, "\(name) 序号")
        }
    }

    func testMansionMapping() {
        let orion = AsterismParser.asterism(for: "参宿四")
        XCTAssertEqual(orion?.name, "参宿")
        XCTAssertEqual(orion?.index, 4)
        XCTAssertEqual(orion?.mansion, "参宿")
        XCTAssertEqual(orion?.symbol, "西方白虎")

        let heart = AsterismParser.asterism(for: "心宿二")
        XCTAssertEqual(heart?.mansion, "心宿")
        XCTAssertEqual(heart?.symbol, "东方青龙")
    }

    func testNonMansionAsterism() {
        let capella = AsterismParser.asterism(for: "五车二")
        XCTAssertEqual(capella?.name, "五车")
        XCTAssertEqual(capella?.index, 2)
        XCTAssertNil(capella?.mansion)
    }

    func testTwoCharacterAsterismWithDoubleDigitIndex() {
        let star = AsterismParser.asterism(for: "天市右垣十一")
        XCTAssertEqual(star?.name, "天市右垣")
        XCTAssertEqual(star?.index, 11)
    }

    func testSingleCharacterPrefixIsNotAnAsterism() {
        XCTAssertNil(AsterismParser.asterism(for: "天一"))
        XCTAssertNil(AsterismParser.asterism(for: "天狼"))
        XCTAssertNil(AsterismParser.asterism(for: "大角"))
    }

    func testNumberParsing() {
        XCTAssertEqual(AsterismParser.number(from: "四"), 4)
        XCTAssertEqual(AsterismParser.number(from: "十"), 10)
        XCTAssertEqual(AsterismParser.number(from: "十一"), 11)
        XCTAssertEqual(AsterismParser.number(from: "十四"), 14)
        XCTAssertEqual(AsterismParser.number(from: "二十"), 20)
        XCTAssertEqual(AsterismParser.number(from: "二十三"), 23)
    }

    func testDisplayPrefersChinese() {
        let star = Star(
            rightAscensionHours: 5.92, declinationDegrees: 7.4, magnitude: 0.45,
            colorIndex: 1.5, name: "Betelgeuse", constellation: "Ori"
        )
        let display = StarDisplay.make(for: star)
        XCTAssertEqual(display.title, "参宿四")
        XCTAssertEqual(display.subtitle, "Betelgeuse")
        XCTAssertEqual(display.asterismLine, "星官 参宿 · 第 4 星")
        XCTAssertEqual(display.mansionLine, "二十八宿 参宿 · 西方白虎")
        XCTAssertEqual(display.constellation, "猎户座")
    }

    func testDisplayFallsBackToLatin() {
        let star = Star(
            rightAscensionHours: 3.77, declinationDegrees: 24.0, magnitude: 4.14,
            colorIndex: 0, name: "Merope", constellation: "Tau"
        )
        let display = StarDisplay.make(for: star)
        XCTAssertEqual(display.title, "昴宿五")
        XCTAssertEqual(display.subtitle, "Merope")
    }

    func testOfficialChineseNameFlagged() {
        let star = Star(
            rightAscensionHours: 5.63, declinationDegrees: 21.1, magnitude: 2.97,
            colorIndex: 0, name: "Tianguan", constellation: "Tau"
        )
        XCTAssertTrue(StarDisplay.make(for: star).official)
        XCTAssertFalse(StarDisplay.make(for: Star(
            rightAscensionHours: 6.75, declinationDegrees: -16.7, magnitude: -1.44,
            colorIndex: 0, name: "Sirius", constellation: "CMa"
        )).official)
    }
}

final class CompanionTests: XCTestCase {
    func testUnresolvableCompanionsAreHidden() throws {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        let byName = Dictionary(grouping: catalog.stars, by: \.name).compactMapValues { $0.first }

        XCTAssertEqual(byName["Castor B"]?.isCompanion, true)
        XCTAssertEqual(byName["Toliman"]?.isCompanion, true)
        XCTAssertEqual(byName["Castor"]?.isCompanion, false)
        XCTAssertEqual(byName["Castor"]?.isSelectable, true)
        XCTAssertEqual(byName["Rigil Kentaurus"]?.isSelectable, true)
    }

    func testCompanionMarkingKeepsBrighterMember() {
        var stars = [
            Star(rightAscensionHours: 6.0, declinationDegrees: 10, magnitude: 1.5, colorIndex: 0, name: "Primary", constellation: "Ori"),
            Star(rightAscensionHours: 6.0, declinationDegrees: 10.001, magnitude: 3.0, colorIndex: 0, name: "Faint", constellation: "Ori"),
            Star(rightAscensionHours: 6.0, declinationDegrees: 40, magnitude: 2.0, colorIndex: 0, name: "Other", constellation: "Ori"),
        ]
        StarCatalog.markCompanions(in: &stars)
        XCTAssertFalse(stars[0].isCompanion)
        XCTAssertTrue(stars[1].isCompanion)
        XCTAssertFalse(stars[2].isCompanion)
    }

    func testSelectableCountAfterMerge() throws {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        XCTAssertEqual(catalog.stars.filter(\.isSelectable).count, 286)
        XCTAssertEqual(catalog.stars.filter { $0.isCompanion }.count, 15)
    }
}

final class FengshenTests: XCTestCase {
    func testBoardMatchesSourceNumbers() {
        XCTAssertEqual(FengshenInfo.all.count, 369)
        XCTAssertEqual(FengshenInfo.all.filter(\.isLocatable).count, 43)
        XCTAssertEqual(Set(FengshenInfo.all.map(\.id)).count, 369)
        XCTAssertEqual(FengshenInfo.departments.count, 15)
    }

    func testDepartmentAndGroupCounts() {
        let counts = Dictionary(grouping: FengshenInfo.all, by: \.department)
            .mapValues(\.count)
        XCTAssertEqual(counts["斗部"], 289)
        XCTAssertEqual(counts["雷部"], 25)
        XCTAssertEqual(counts["太岁部"], 12)
        XCTAssertEqual(counts["瘟部"], 7)
        XCTAssertEqual(counts["痘部"], 7)
        XCTAssertEqual(counts["三山五岳"], 6)
        XCTAssertEqual(counts["财部"], 5)

        let groups = Dictionary(grouping: FengshenInfo.all, by: \.group)
            .mapValues(\.count)
        XCTAssertEqual(groups["群星"], 115)
        XCTAssertEqual(groups["天罡三十六"], 36)
        XCTAssertEqual(groups["地煞七十二"], 72)
        XCTAssertEqual(groups["九曜"], 9)
        XCTAssertEqual(groups["二十八宿"], 28)
        XCTAssertEqual(groups["五斗星官"], 28)
        XCTAssertEqual(groups["二十四天君"], 24)
        XCTAssertEqual(groups["日直众星"], 10)
        XCTAssertEqual(groups["五方主痘正神"], 5)
    }

    func testTwentyEightMansionsAreAllPresent() {
        for symbol in TwentyEightMansions.groups {
            for mansion in symbol.mansions {
                XCTAssertNotNil(FengshenInfo.entry(forMansion: mansion), "\(mansion) 宿缺少封神名号")
            }
        }
        XCTAssertEqual(FengshenInfo.lords(forAsterism: "角宿").count, 1)
    }

    func testEightMansionsAlsoServeWaterOrFire() {
        let assigned = FengshenInfo.all.filter { $0.alsoServes != nil }
        XCTAssertEqual(assigned.count, 8)
        let fire = assigned.filter { $0.alsoServes == "火部" }.compactMap(\.mansion).sorted()
        let water = assigned.filter { $0.alsoServes == "水部" }.compactMap(\.mansion).sorted()
        XCTAssertEqual(fire, ["室", "尾", "翼", "觜"])
        XCTAssertEqual(water, ["参", "壁", "箕", "轸"])
    }

    func testMansionLookupFromFullName() {
        XCTAssertEqual(FengshenInfo.entry(forMansion: "参宿")?.title, "参水猿")
        XCTAssertEqual(FengshenInfo.entry(forMansion: "参宿")?.person, "孙祥")
        XCTAssertNil(FengshenInfo.entry(forMansion: "五车"))
    }

    func testEveryLocatableLordPointsAtARealAsterism() {
        let names = Set(AsterismCatalog.all.map(\.name))
        for lord in FengshenInfo.all where lord.isLocatable {
            XCTAssertTrue(names.contains(lord.asterism ?? ""), "\(lord.title) 指向不存在的星官：\(lord.asterism ?? "nil")")
        }
    }

    func testStarCardLine() {
        let orion = Star(
            rightAscensionHours: 5.92, declinationDegrees: 7.4, magnitude: 0.45,
            colorIndex: 1.5, name: "Betelgeuse", constellation: "Ori"
        )
        XCTAssertEqual(StarDisplay.make(for: orion).fengshenLine, "封神 参水猿 · 孙祥")

        let dubhe = Star(
            rightAscensionHours: 11.06, declinationDegrees: 61.75, magnitude: 1.81,
            colorIndex: 1.1, name: "Dubhe", constellation: "UMa"
        )
        XCTAssertEqual(StarDisplay.make(for: dubhe).fengshenLine, "封神 9 位星君")
    }

    func testSearchHitsTitlePersonAndDepartment() {
        XCTAssertEqual(FengshenInfo.search("角木蛟").first?.person, "柏林")
        XCTAssertEqual(FengshenInfo.search("闻仲").first?.title, "九天应元雷神普化天尊")
        XCTAssertEqual(FengshenInfo.search("天魁星").first?.person, "高衍")
        XCTAssertTrue(FengshenInfo.search("斗部").count > 200)
        XCTAssertTrue(FengshenInfo.search("").isEmpty)
    }

    func testShuihuRosterCoversAll108() {
        let roster = FengshenInfo.shuihuRoster
        XCTAssertEqual(roster.count, 108)
        XCTAssertEqual(roster.compactMap { $0.shuihu?.rank }, Array(1...108))
        XCTAssertEqual(roster.first?.shuihu?.person, "宋江")
        XCTAssertEqual(roster.last?.shuihu?.person, "段景住")
        XCTAssertEqual(roster.filter { $0.group == "天罡三十六" }.count, 36)
        XCTAssertEqual(roster.filter { $0.group == "地煞七十二" }.count, 72)
    }

    func testShuihuStarNamesMatchFengshenExceptSeven() {
        let differing = FengshenInfo.shuihuRoster.filter { lord in
            guard let star = lord.shuihu?.star else { return false }
            return star != lord.title
        }
        XCTAssertEqual(differing.count, 7)
        let pairs = Set(differing.compactMap { lord in
            lord.shuihu.map { "\(lord.title)/\($0.star)" }
        })
        XCTAssertEqual(pairs, [
            "天玄星/天立星", "天健星/天捷星", "天煞星/天杀星",
            "地辅星/地轴星", "地祐星/地佑星", "地默星/地然星", "地魂星/地丑星",
        ])
    }

    func testShuihuPeopleAreSearchable() {
        XCTAssertEqual(FengshenInfo.search("宋江").first?.shuihu?.rank, 1)
        XCTAssertEqual(FengshenInfo.search("黑旋风").first?.shuihu?.person, "李逵")
        XCTAssertEqual(FengshenInfo.search("段景住").first?.shuihu?.rank, 108)
    }

    func testEveryDepartmentHasANote() {
        for department in FengshenInfo.departments {
            XCTAssertNotNil(FengshenInfo.departmentNotes[department], department)
        }
        XCTAssertEqual(FengshenInfo.departmentNotes.count, FengshenInfo.departments.count)
    }

    func testLocateResolvesAsterismToGroup() throws {
        let stars = try XCTUnwrap(StarCatalog.loadFromBundle(.main)).stars
        let groups = SkyGroupIndex.groups(stars: stars)
        XCTAssertEqual(SkyGroupIndex.group(forAsterism: "角宿", in: groups)?.title, "角宿")
        XCTAssertEqual(SkyGroupIndex.group(forAsterism: "北斗", in: groups)?.title, "北斗")
        XCTAssertEqual(SkyGroupIndex.group(forAsterism: "斗宿", in: groups)?.title, "斗宿")
        XCTAssertNil(SkyGroupIndex.group(forAsterism: "不存在的官", in: groups))
    }

    func testAsterismGroupsCarryFengshenTitles() throws {
        let stars = try XCTUnwrap(StarCatalog.loadFromBundle(.main)).stars
        let groups = SkyGroupIndex.groups(stars: stars)
        let byTitle = Dictionary(groups.map { ($0.title, $0) }, uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(byTitle["参宿"]?.fengshenTitles, ["参水猿"])
        XCTAssertEqual(byTitle["北斗"]?.fengshenTitles.count, 9)
        XCTAssertEqual(byTitle["北斗"]?.fengshenLine, "封神 9 位星君")
        XCTAssertNil(byTitle["猎户座"]?.fengshenLine)
    }
}

final class ConstellationShapeTests: XCTestCase {
    private func positions() throws -> [String: SIMD3<Float>] {
        let stars = try XCTUnwrap(StarCatalog.loadFromBundle(.main)).stars
        var map: [String: SIMD3<Float>] = [:]
        for star in stars where star.isNamed && map[star.name] == nil {
            map[star.name] = StarField.position(for: star)
        }
        return map
    }

    func testMultiRingConstellationsAreDeclared() {
        let byAbbreviation = Dictionary(
            Constellations.all.map { ($0.abbreviation, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        XCTAssertEqual(byAbbreviation["Gem"]?.outlines.count, 2)
        XCTAssertEqual(byAbbreviation["Tau"]?.outlines.count, 2)
        XCTAssertEqual(byAbbreviation["Peg"]?.outlines.count, 2)
        XCTAssertTrue(byAbbreviation["Gem"]?.outline.isEmpty == true)
    }

    func testEveryRingReferencesRealStarsAndHasThreePoints() throws {
        let map = try positions()
        for constellation in Constellations.all {
            for ring in constellation.outlines {
                XCTAssertGreaterThanOrEqual(ring.count, 3, "\(constellation.name) 轮廓环点数不足")
                for name in ring {
                    XCTAssertNotNil(map[name], "\(constellation.name) 轮廓引用了不存在的星：\(name)")
                }
            }
            if !constellation.outline.isEmpty {
                for name in constellation.outline {
                    XCTAssertNotNil(map[name], "\(constellation.name) 轮廓引用了不存在的星：\(name)")
                }
            }
        }
    }

    @MainActor
    func testEveryDrawnConstellationProducesAShape() throws {
        let map = try positions()
        var shaped = 0
        for constellation in Constellations.primary {
            let rings = SkyScene.fillRings(for: constellation, positions: map)
            guard !rings.isEmpty else { continue }
            let shape = ConstellationFigureBuilder.shape(
                key: constellation.abbreviation,
                rings: rings
            )
            let unwrapped = try XCTUnwrap(shape, constellation.name)
            XCTAssertGreaterThan(unwrapped.rings.count, 0, constellation.name)
            XCTAssertLessThan(unwrapped.radiusDegrees, 90, constellation.name)
            shaped += 1
        }
        // 31 座里 13 座写了轮廓环、2 座有美术图形，合计 15 座画填充；
        // 其余 16 座（天蝎、狮子等）原本靠凸包兜底，凸包会把钩子和镰刀填成一块饼，
        // 现在只画骨架，不再假装自己有轮廓。
        XCTAssertEqual(shaped, 15)
    }

    @MainActor
    func testShapeRejectsOppositeAndMostCentersHit() throws {
        let map = try positions()
        var centered = 0
        var total = 0
        for constellation in Constellations.primary {
            let rings = SkyScene.fillRings(for: constellation, positions: map)
            guard let shape = ConstellationFigureBuilder.shape(
                key: constellation.abbreviation,
                rings: rings
            ) else { continue }
            total += 1
            XCTAssertFalse(
                shape.contains(-shape.center),
                "\(constellation.name) 把对跖点也判进来了"
            )
            if shape.contains(shape.center) {
                centered += 1
            }
        }
        // 凹形（仙后 W、天鹅十字）与多环（双子、金牛）的几何中心本就落在轮廓之外，
        // 这里只要求绝大多数命中，防止包含判定整体失效。
        XCTAssertEqual(total, 15)
        XCTAssertGreaterThanOrEqual(centered, 10, "命中比例过低，判定可能失效")
    }

    @MainActor
    func testMultiRingShapesAreSeparated() throws {
        let map = try positions()
        let gemini = try XCTUnwrap(Constellations.primary.first { $0.abbreviation == "Gem" })
        let rings = SkyScene.fillRings(for: gemini, positions: map)
        XCTAssertEqual(rings.count, 2)
        for ring in rings {
            XCTAssertGreaterThanOrEqual(ring.count, 3)
        }
        let centers = rings.map { ring -> SIMD3<Float> in
            ring.reduce(SIMD3<Float>(0, 0, 0), +) / Float(ring.count)
        }
        let separation = acos(Double(min(max(simd_dot(
            simd_normalize(centers[0]),
            simd_normalize(centers[1])
        ), -1), 1))) * 180 / .pi
        XCTAssertGreaterThan(separation, 2, "双子两个环的中心太近，画不出两个人形")
    }
}

final class ConstellationOutlineTests: XCTestCase {
    func testOutlinesReferenceRealStars() throws {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        let names = Set(catalog.stars.map(\.name))
        for constellation in Constellations.all where !constellation.outline.isEmpty {
            let missing = constellation.outline.filter { !names.contains($0) }
            XCTAssertTrue(missing.isEmpty, "\(constellation.name) 轮廓引用了不存在的星：\(missing)")
            XCTAssertGreaterThanOrEqual(constellation.outline.count, 3)
        }
    }

    func testPolygonTriangulatesRing() {
        let ring = [
            SIMD3<Float>(0, 0, -50),
            SIMD3<Float>(1, 0, -50),
            SIMD3<Float>(1, 1, -50),
        ]
        let mesh = StarFieldBuilder.polygon(ring: ring, radius: 51)
        XCTAssertEqual(mesh.positions.count, 3)
        XCTAssertEqual(mesh.indices.count, 6)
        for position in mesh.positions {
            XCTAssertEqual(simd_length(position), 51, accuracy: 0.001)
        }
    }

    func testTriangulationHandlesConcaveRing() {
        let ring = [
            SIMD2<Float>(0, 0), SIMD2<Float>(3, 0), SIMD2<Float>(3, 3),
            SIMD2<Float>(2, 3), SIMD2<Float>(2, 1), SIMD2<Float>(0, 1),
        ]
        let triangles = StarFieldBuilder.triangulate(ring)
        XCTAssertEqual(triangles.count, ring.count - 2)

        var total: Float = 0
        for triangle in triangles {
            let a = ring[triangle.0]
            let b = ring[triangle.1]
            let c = ring[triangle.2]
            total += abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) / 2
        }
        XCTAssertEqual(total, abs(StarFieldBuilder.signedArea(ring)), accuracy: 0.0001)
        XCTAssertEqual(total, 5, accuracy: 0.0001)
    }

    func testTriangulationAcceptsClockwiseRing() {
        let ring = [
            SIMD2<Float>(0, 0), SIMD2<Float>(0, 2), SIMD2<Float>(2, 2), SIMD2<Float>(2, 0),
        ]
        XCTAssertEqual(StarFieldBuilder.triangulate(ring).count, 2)
    }

    func testConvexHullDropsInteriorPoints() {
        let points = [
            SIMD2<Float>(0, 0), SIMD2<Float>(1, 0), SIMD2<Float>(1, 1),
            SIMD2<Float>(0, 1), SIMD2<Float>(0.5, 0.5),
        ]
        let hull = StarFieldBuilder.convexHull(points)
        XCTAssertEqual(hull.count, 4)
        XCTAssertFalse(hull.contains(4))
    }
}

final class ConstellationFigureTests: XCTestCase {
    private func positions() throws -> [String: SIMD3<Float>] {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        var result: [String: SIMD3<Float>] = [:]
        for star in catalog.stars where star.isNamed && result[star.name] == nil {
            result[star.name] = StarField.position(for: star)
        }
        return result
    }

    func testFiguresTargetDrawnConstellations() {
        let drawn = Set(Constellations.all.map(\.abbreviation))
        for abbreviation in ConstellationFigures.all.keys {
            XCTAssertTrue(drawn.contains(abbreviation), "\(abbreviation) 没有连线数据")
        }
    }

    func testAnchorsExistAndAreEnclosed() throws {
        let positions = try positions()
        for (abbreviation, figure) in ConstellationFigures.all {
            for anchor in figure.anchors {
                XCTAssertNotNil(positions[anchor], "\(abbreviation) 的锚点星不存在：\(anchor)")
                XCTAssertTrue(
                    ConstellationFigureBuilder.isInside(anchor, figure: figure, positions: positions),
                    "\(abbreviation) 的轮廓没有包住锚点星 \(anchor)"
                )
            }
        }
    }

    func testRingsAreWellFormed() {
        for (abbreviation, figure) in ConstellationFigures.all {
            XCTAssertGreaterThanOrEqual(figure.rings.count, 1, abbreviation)
            for ring in figure.rings {
                XCTAssertGreaterThanOrEqual(ring.count, 3, abbreviation)
                for point in ring {
                    XCTAssertLessThanOrEqual(abs(point.x), 1.5, abbreviation)
                    XCTAssertLessThanOrEqual(abs(point.y), 1.5, abbreviation)
                }
            }
        }
    }

    func testBuilderReturnsOneRingPerRing() throws {
        let positions = try positions()
        let figure = try XCTUnwrap(ConstellationFigures.all["UMa"])
        let rings = ConstellationFigureBuilder.rings(figure, positions: positions)
        XCTAssertEqual(rings.count, figure.rings.count)
        for ring in rings {
            XCTAssertEqual(ring.count, figure.rings.first?.count)
            for direction in ring {
                XCTAssertEqual(simd_length(direction), 1, accuracy: 0.0005)
            }
        }
    }

    func testBuilderRejectsMissingAnchors() {
        let figure = ConstellationFigure(anchors: ["不存在的星"], rings: [[SIMD2<Float>(0, 0), SIMD2<Float>(1, 0), SIMD2<Float>(0, 1)]])
        XCTAssertTrue(ConstellationFigureBuilder.rings(figure, positions: [:]).isEmpty)
    }

    func testNormalizedReversesDirection() throws {
        let positions = try positions()
        let figure = try XCTUnwrap(ConstellationFigures.all["Sco"])
        let frame = try XCTUnwrap(ConstellationFigureBuilder.Frame(figure: figure, positions: positions))
        for point in [SIMD2<Float>(0, 0), SIMD2<Float>(0.6, -0.3), SIMD2<Float>(-0.9, 0.7)] {
            let direction = try XCTUnwrap(frame.direction(point))
            let roundTrip = try XCTUnwrap(frame.normalized(direction))
            XCTAssertEqual(roundTrip.x, point.x, accuracy: 0.02)
            XCTAssertEqual(roundTrip.y, point.y, accuracy: 0.02)
        }
    }
}

final class AsterismCatalogTests: XCTestCase {
    func testCatalogMatchesGeneratedNumbers() {
        let all = AsterismCatalog.all
        XCTAssertEqual(all.count, 301)
        XCTAssertEqual(all.filter(\.isDrawable).count, 227)
        XCTAssertEqual(all.reduce(0) { $0 + $1.segmentCount }, 814)
        XCTAssertEqual(all.filter(\.isMansion).count, 28)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
    }

    func testEveryAsterismHasAVisibleMember() throws {
        let stars = try XCTUnwrap(StarCatalog.loadFromBundle(.main)).stars
        let hips = Set(stars.compactMap(\.hipparcos))
        for asterism in AsterismCatalog.all {
            XCTAssertTrue(asterism.members.contains { hips.contains($0) }, asterism.name)
        }
    }

    func testDrawableAsterismsResolveInCatalog() throws {
        let stars = try XCTUnwrap(StarCatalog.loadFromBundle(.main)).stars
        let hips = Set(stars.compactMap(\.hipparcos))
        for asterism in AsterismCatalog.all where asterism.isDrawable {
            let resolved = asterism.lines.reduce(0) { total, line in
                total + max(line.filter { hips.contains($0) }.count - 1, 0)
            }
            XCTAssertGreaterThan(resolved, 0, asterism.name)
        }
    }
}

final class SkyGroupTests: XCTestCase {
    private func catalog() throws -> [Star] {
        try XCTUnwrap(StarCatalog.loadFromBundle(.main)).stars
    }

    func testAsterismGroupsMatchKnownCounts() throws {
        let groups = SkyGroupIndex.groups(stars: try catalog())
        let byTitle = Dictionary(grouping: groups, by: \.title).compactMapValues { $0.first }

        XCTAssertEqual(byTitle["参宿"]?.memberCount, 7)
        XCTAssertEqual(byTitle["昴宿"]?.memberCount, 6)
        XCTAssertEqual(byTitle["五车"]?.memberCount, 5)
        XCTAssertEqual(byTitle["北斗"]?.memberCount, 7)
        XCTAssertNil(byTitle["北斗七星"])
        XCTAssertEqual(byTitle["参宿"]?.kind, .mansion)
        XCTAssertEqual(byTitle["五车"]?.kind, .asterism)
        XCTAssertEqual(byTitle["参宿"]?.lineCount, 6)
        XCTAssertEqual(byTitle["角宿"]?.lineCount, 1)
        XCTAssertEqual(byTitle["北斗"]?.isDrawable, true)
    }

    func testGroupsAreUniqueAndSelectableOnly() throws {
        let stars = try catalog()
        let groups = SkyGroupIndex.groups(stars: stars)
        let selectable = Set(stars.filter(\.isSelectable).map(\.name))

        XCTAssertEqual(Set(groups.map(\.id)).count, groups.count)
        for group in groups {
            XCTAssertTrue(Set(group.starNames).isSubset(of: selectable), group.title)
            XCTAssertGreaterThanOrEqual(group.memberCount, 1, group.title)
        }
    }

    func testSearchByFengshenName() throws {
        let groups = SkyGroupIndex.groups(stars: try catalog())
        XCTAssertEqual(SkyGroupIndex.search(groups, query: "参水猿").first?.title, "参宿")
        XCTAssertEqual(SkyGroupIndex.search(groups, query: "角木蛟").first?.title, "角宿")
    }

    func testSearchByMansionAndConstellation() throws {
        let groups = SkyGroupIndex.groups(stars: try catalog())
        XCTAssertEqual(SkyGroupIndex.search(groups, query: "心宿").first?.title, "心宿")
        XCTAssertEqual(SkyGroupIndex.search(groups, query: "猎户").first?.title, "猎户座")
        XCTAssertEqual(SkyGroupIndex.search(groups, query: "北斗").first?.title, "北斗")
        XCTAssertEqual(SkyGroupIndex.search(groups, query: "北斗七星").first?.title, "北斗")
        XCTAssertEqual(SkyGroupIndex.search(groups, query: "大三角").first?.kind, .curated)
    }

    func testAnchorSitsAtGroupCentroid() throws {
        let stars = try catalog()
        let groups = SkyGroupIndex.groups(stars: stars)
        let pleiades = try XCTUnwrap(groups.first { $0.title == "昴宿" })
        let anchor = try XCTUnwrap(SkyGroupIndex.anchor(pleiades, stars: stars))
        let alcyone = try XCTUnwrap(stars.first { $0.name == "Alcyone" })
        let alignment = simd_dot(anchor, SkyPicker.direction(for: alcyone))

        XCTAssertEqual(simd_length(anchor), 1, accuracy: 0.0005)
        XCTAssertGreaterThan(alignment, 0.99)
    }

    func testBrightestAndMembersOrdering() throws {
        let stars = try catalog()
        let groups = SkyGroupIndex.groups(stars: stars)
        let orion = try XCTUnwrap(groups.first { $0.title == "参宿" })
        XCTAssertEqual(SkyGroupIndex.brightest(orion, stars: stars)?.name, "Rigel")

        let members = SkyGroupIndex.members(orion, stars: stars, limit: 3)
        XCTAssertEqual(members.map(\.name), ["Rigel", "Betelgeuse", "Bellatrix"])
    }
}

final class TimeScrubTests: XCTestCase {
    private let reference = Date(timeIntervalSince1970: 1_768_000_000)

    func testSiderealAdvancesFifteenDegreesPerHour() {
        let base = Date(timeIntervalSince1970: 1_768_000_000)
        let first = Astronomy.localSiderealDegrees(
            julianDay: Astronomy.julianDay(base),
            longitude: 116.4
        )
        let second = Astronomy.localSiderealDegrees(
            julianDay: Astronomy.julianDay(base.addingTimeInterval(3600)),
            longitude: 116.4
        )
        XCTAssertEqual(Astronomy.normalized(second - first), 15.041, accuracy: 0.02)
    }

    func testTwelveHourShiftMovesSiderealHalfTurn() {
        let base = Date(timeIntervalSince1970: 1_768_000_000)
        let first = Astronomy.localSiderealDegrees(
            julianDay: Astronomy.julianDay(base),
            longitude: 120.6
        )
        let later = Astronomy.localSiderealDegrees(
            julianDay: Astronomy.julianDay(base.addingTimeInterval(12 * 3600)),
            longitude: 120.6
        )
        XCTAssertEqual(Astronomy.normalized(later - first), 180.5, accuracy: 0.5)
    }

    func testClockFollowsRealTimeWhenAtNow() {
        let clock = SkyClock(base: reference)
        let probe = reference.addingTimeInterval(7200)
        XCTAssertEqual(clock.instant(now: probe), probe)
        XCTAssertTrue(clock.isNow)
    }

    func testClockFreezesInstantOnceOffsetIsSet() {
        var clock = SkyClock(base: reference)
        let draggedAt = reference.addingTimeInterval(100)
        clock.setOffset(hours: 3, at: draggedAt)
        let early = clock.instant(now: reference)
        let late = clock.instant(now: reference.addingTimeInterval(600))
        XCTAssertEqual(early, late)
        XCTAssertEqual(early, draggedAt.addingTimeInterval(3 * 3600))
    }

    func testClockKeepsBaseWhileStillFollowingTime() {
        var clock = SkyClock(base: reference)
        clock.setOffset(hours: 0.0001)
        XCTAssertEqual(clock.base, reference)
        XCTAssertTrue(clock.isNow)
    }

    func testClockClampsOffsetToWholeDay() {
        var clock = SkyClock(base: reference)
        clock.setOffset(hours: 40)
        XCTAssertEqual(clock.offsetHours, 24, accuracy: 0.0001)
        clock.setOffset(hours: -40)
        XCTAssertEqual(clock.offsetHours, -24, accuracy: 0.0001)
    }

    func testClockResetReturnsToNow() {
        var clock = SkyClock(base: reference, offsetHours: -6)
        clock.reset(to: reference)
        XCTAssertTrue(clock.isNow)
        XCTAssertEqual(clock.instant(now: reference), reference)
    }

    func testClockTreatsSubThirtySecondsAsNow() {
        var clock = SkyClock(base: reference)
        clock.setOffset(hours: 1.0 / 240)
        XCTAssertTrue(clock.isNow)
    }

    func testFieldRotationMatchesOneHourOfSidereal() {
        let before = Astronomy.equatorialToHorizontalRotation(siderealDegrees: 100, latitude: 31.25)
        let after = Astronomy.equatorialToHorizontalRotation(siderealDegrees: 115.041, latitude: 31.25)
        let delta = before.inverse * after
        let degrees = abs(Double(delta.angle) * 180 / .pi)
        XCTAssertEqual(degrees, 15.041, accuracy: 0.01)
    }

    func testSameOffsetYieldsSameInstant() {
        let clock = SkyClock(base: reference, offsetHours: 3)
        let first = clock.instant(now: reference)
        let second = clock.instant(now: reference.addingTimeInterval(600))
        XCTAssertEqual(first, second)
    }

    func testMinuteStepsProduceConstantSiderealAdvance() {
        var clock = SkyClock(base: reference)
        let longitude = 120.6
        var previous: Double?
        var deltas: [Double] = []

        for minute in stride(from: -720, through: 720, by: 1) {
            clock.setOffset(hours: Double(minute) / 60, at: reference)
            let julian = Astronomy.julianDay(clock.instant(now: reference))
            let sidereal = Astronomy.localSiderealDegrees(julianDay: julian, longitude: longitude)
            if let previous {
                deltas.append(Astronomy.normalized(sidereal - previous))
            }
            previous = sidereal
        }

        XCTAssertEqual(deltas.count, 1440)
        XCTAssertEqual(deltas.min() ?? 0, 0.2507, accuracy: 0.002)
        XCTAssertEqual(deltas.max() ?? 0, 0.2507, accuracy: 0.002)
    }

    func testSliderBoundsStayInsideOneDay() {
        var clock = SkyClock(base: reference)
        clock.setOffset(hours: 12, at: reference)
        XCTAssertEqual(clock.offsetHours, 12)
        clock.setOffset(hours: -12, at: reference)
        XCTAssertEqual(clock.offsetHours, -12)
    }
}

final class ConstellationFactsTests: XCTestCase {
    func testEveryConstellationHasLore() {
        let abbreviations = Set(ConstellationInfo.latinNames.keys)
        XCTAssertEqual(abbreviations.count, 88)
        for abbreviation in abbreviations {
            let fact = ConstellationInfo.fact(for: abbreviation)
            XCTAssertNotNil(fact, abbreviation)
            XCTAssertFalse(fact?.westernLore.isEmpty ?? true, abbreviation)
            XCTAssertFalse(fact?.chineseLore.isEmpty ?? true, abbreviation)
        }
    }

    func testFactsMatchTheirKeys() {
        for (key, fact) in ConstellationInfo.facts {
            XCTAssertEqual(key, fact.abbreviation)
        }
    }

    func testLoreLengthIsReadable() {
        for (key, fact) in ConstellationInfo.facts {
            XCTAssertGreaterThan(fact.westernLore.count, 10, key)
            XCTAssertGreaterThan(fact.chineseLore.count, 6, key)
            XCTAssertLessThan(fact.westernLore.count, 90, key)
            XCTAssertLessThan(fact.chineseLore.count, 90, key)
        }
    }
}

final class TonightTourTests: XCTestCase {
    private func pick(
        title: String,
        altitude: Double,
        azimuth: Double = 135,
        magnitude: Double = 1.0,
        members: Int = 6
    ) -> TonightPick {
        TonightPick(
            group: SkyGroup(
                id: "constellation:\(title)",
                kind: .constellation,
                title: title,
                starNames: Array(repeating: "S", count: members)
            ),
            altitude: altitude,
            azimuth: azimuth,
            bestMonths: [10, 11, 12],
            magnitude: magnitude
        )
    }

    func testEmptyPicksBuildNothing() {
        XCTAssertNil(TonightTour.build(picks: [], date: Date(timeIntervalSince1970: 0)))
    }

    func testStopsAreLimitedAndOrdered() {
        let picks = (1...6).map { pick(title: "星座\($0)", altitude: Double(80 - $0 * 5)) }
        let tour = TonightTour.build(picks: picks, date: Date(timeIntervalSince1970: 0), limit: 4)
        XCTAssertEqual(tour?.stops.count, 4)
        XCTAssertEqual(tour?.stops.map(\.order), [1, 2, 3, 4])
        XCTAssertEqual(tour?.stops.first?.pick.group.title, "星座1")
    }

    func testPlacementWording() {
        XCTAssertEqual(TonightTour.placement(pick(title: "A", altitude: 82)), "几乎就在头顶")
        XCTAssertTrue(TonightTour.placement(pick(title: "A", altitude: 55)).hasPrefix("高悬在东"))
        XCTAssertTrue(TonightTour.placement(pick(title: "A", altitude: 30)).contains("约 30°"))
        XCTAssertTrue(TonightTour.placement(pick(title: "A", altitude: 15)).hasPrefix("刚爬上东"))
    }

    func testEveryPrimaryConstellationHasATip() {
        // 导览提示是照着 31 座手工星座写的；南天暗座不参与今夜导览。
        for constellation in Constellations.primary {
            XCTAssertNotNil(SkyTips.tips[constellation.name], constellation.name)
        }
    }

    func testHeadlineNamesTheLeadingTarget() {
        let tour = TonightTour.build(
            picks: [pick(title: "猎户座", altitude: 48)],
            date: Date(timeIntervalSince1970: 0)
        )
        XCTAssertTrue(tour?.headline.contains("猎户座") == true)
        XCTAssertTrue(tour?.headline.contains("高悬") == true)
    }
}

final class SkySeasonTests: XCTestCase {
    private func stars() throws -> [Star] {
        try XCTUnwrap(StarCatalog.loadFromBundle(.main)).stars
    }

    private func beijingMidJanuary() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        components.hour = 14
        components.minute = 0
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 1_768_000_000)
    }

    func testBestMonthsWindowWrapsAtNewYear() {
        XCTAssertEqual(SkySeason.bestMonths(rightAscensionHours: 5.6), [12, 1, 2])
        XCTAssertEqual(SkySeason.bestMonths(rightAscensionHours: 16.5), [5, 6, 7])
        XCTAssertEqual(SkySeason.bestMonths(rightAscensionHours: 22), [8, 9, 10])
    }

    func testSeasonLabelHandlesYearBoundary() {
        XCTAssertEqual(SkySeason.label([12, 1, 2]), "12 月 – 次年 2 月")
        XCTAssertEqual(SkySeason.label([10, 11, 12]), "10–12 月")
        XCTAssertEqual(SkySeason.label([1, 2, 3]), "1–3 月")
    }

    func testDirectionLabels() {
        XCTAssertEqual(SkySeason.directionLabel(azimuth: 0), "北")
        XCTAssertEqual(SkySeason.directionLabel(azimuth: 90), "东")
        XCTAssertEqual(SkySeason.directionLabel(azimuth: 180), "南")
        XCTAssertEqual(SkySeason.directionLabel(azimuth: 275), "西")
        XCTAssertEqual(SkySeason.directionLabel(azimuth: 350), "北")
    }

    func testGroupCoordinateMatchesMembers() throws {
        let stars = try stars()
        let groups = SkyGroupIndex.groups(stars: stars)
        let orion = try XCTUnwrap(groups.first { $0.title == "猎户座" })
        let coordinate = try XCTUnwrap(SkySeason.coordinate(orion, stars: stars))

        XCTAssertEqual(coordinate.rightAscension, 5.6, accuracy: 0.4)
        XCTAssertEqual(coordinate.declination, 0, accuracy: 8)
    }

    func testTonightRankingAtBeijingMidJanuary() throws {
        let stars = try stars()
        let groups = SkyGroupIndex.groups(stars: stars)
        let picks = SkySeason.rank(
            groups: groups,
            stars: stars,
            latitude: 31.25,
            longitude: 120.6,
            date: beijingMidJanuary(),
            limit: 5
        )

        XCTAssertFalse(picks.isEmpty)
        XCTAssertLessThanOrEqual(picks.count, 5)
        XCTAssertTrue(picks.contains { $0.group.title == "猎户座" })
        XCTAssertGreaterThan(picks.first?.altitude ?? 0, 60)
        for pick in picks {
            XCTAssertGreaterThan(pick.altitude, 12)
            XCTAssertEqual(pick.group.kind, .constellation)
        }
        let scores = picks.map(SkySeason.score)
        XCTAssertEqual(scores, scores.sorted(by: >))
    }

    func testAltitudeDrivesScore() {
        let group = SkyGroup(
            id: "constellation:Test", kind: .constellation, title: "测试",
            starNames: []
        )
        let low = TonightPick(group: group, altitude: 15, azimuth: 90, bestMonths: [1, 2, 3], magnitude: 0)
        let high = TonightPick(group: group, altitude: 75, azimuth: 180, bestMonths: [1, 2, 3], magnitude: 0)
        XCTAssertGreaterThan(SkySeason.score(high), SkySeason.score(low))
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

final class SkyPatternTests: XCTestCase {
    private func positions() throws -> [String: SIMD3<Float>] {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        var result: [String: SIMD3<Float>] = [:]
        for star in catalog.stars where star.isNamed && result[star.name] == nil {
            result[star.name] = StarField.position(for: star)
        }
        return result
    }

    func testIdentifiersAreUniqueAndNamed() {
        var seen = Set<String>()
        for pattern in SkyPatternCatalog.all {
            XCTAssertFalse(pattern.id.isEmpty)
            XCTAssertTrue(seen.insert(pattern.id).inserted, "星群 id 重复：\(pattern.id)")
            XCTAssertFalse(pattern.name.isEmpty)
            XCTAssertFalse(pattern.latin.isEmpty)
            XCTAssertGreaterThanOrEqual(pattern.anchors.count, 3, pattern.name)
            XCTAssertEqual(pattern.starCount, Set(pattern.anchors).count)
        }
    }

    func testAnchorsExistInCatalog() throws {
        let map = try positions()
        for pattern in SkyPatternCatalog.all {
            for anchor in pattern.anchors {
                XCTAssertNotNil(map[anchor], "\(pattern.name) 引用了星表里没有的星：\(anchor)")
            }
        }
    }

    func testClosedPatternsHaveInterior() throws {
        let map = try positions()
        var closed = 0
        for pattern in SkyPatternCatalog.all where pattern.closed {
            closed += 1
            let ring = try XCTUnwrap(SkyPatternGeometry.ring(for: pattern, positions: map), pattern.name)
            let shape = try XCTUnwrap(
                ConstellationFigureBuilder.shape(key: pattern.id, rings: [ring]),
                pattern.name
            )
            XCTAssertEqual(shape.key, pattern.id)
            XCTAssertTrue(shape.contains(shape.center), "\(pattern.name) 的几何中心不在自己内部")
            XCTAssertFalse(shape.contains(-shape.center), "\(pattern.name) 把对跖点也判进来了")
            XCTAssertLessThan(shape.radiusDegrees, 90, pattern.name)
        }
        // 冬季大三角、夏季大三角闭合；春季大弧线是折线。
        XCTAssertEqual(closed, 2)
    }

    func testOpenPatternHasNoInterior() throws {
        let map = try positions()
        let arc = try XCTUnwrap(SkyPatternCatalog.pattern(id: "spring-arc"))
        XCTAssertFalse(arc.closed)
        XCTAssertNil(SkyPatternGeometry.ring(for: arc, positions: map), "折线星群不该有可判定内部")
    }

    func testDashesLeaveGaps() {
        let start = StarField.direction(rightAscensionHours: 6, declinationDegrees: 0)
        let end = StarField.direction(rightAscensionHours: 8, declinationDegrees: 10)
        let total = acos(Double(simd_dot(start, end))) * 180 / .pi
        let dashes = SkyPatternGeometry.dashes(from: start, to: end)
        XCTAssertGreaterThan(dashes.count, 3)

        var covered = 0.0
        for dash in dashes {
            XCTAssertEqual(simd_length(dash.0), 1, accuracy: 0.0005)
            XCTAssertEqual(simd_length(dash.1), 1, accuracy: 0.0005)
            covered += acos(Double(min(max(simd_dot(
                simd_normalize(dash.0),
                simd_normalize(dash.1)
            ), -1), 1))) * 180 / .pi
        }
        XCTAssertEqual(covered / total, 1 - SkyPatternGeometry.gapRatio, accuracy: 0.01)
    }

    func testSegmentsSitOnRequestedRadius() throws {
        let map = try positions()
        for pattern in SkyPatternCatalog.all {
            let edges = pattern.anchors.count - 1 + (pattern.closed ? 1 : 0)
            let segments = SkyPatternGeometry.segments(for: pattern, positions: map, radius: 49)
            XCTAssertGreaterThanOrEqual(segments.count, edges, "\(pattern.name) 有边没画出虚线")
            for segment in segments {
                XCTAssertEqual(simd_length(segment.0), 49, accuracy: 0.01)
                XCTAssertEqual(simd_length(segment.1), 49, accuracy: 0.01)
            }
        }
    }

    func testDashesClearTheAnchorStars() throws {
        let map = try positions()
        for pattern in SkyPatternCatalog.all {
            let anchors = pattern.anchors.compactMap { map[$0] }
            XCTAssertEqual(anchors.count, pattern.anchors.count, pattern.name)
            for segment in SkyPatternGeometry.segments(for: pattern, positions: map, radius: 49) {
                for anchor in anchors {
                    let gap = min(
                        SkyPatternGeometry.angleDegrees(segment.0, anchor),
                        SkyPatternGeometry.angleDegrees(segment.1, anchor)
                    )
                    XCTAssertGreaterThanOrEqual(
                        gap,
                        SkyPatternGeometry.anchorInsetDegrees - 0.01,
                        "\(pattern.name) 的虚线碰到了锚星"
                    )
                }
            }
        }
    }

    func testPolylinesDoNotBacktrack() throws {
        let map = try positions()
        for pattern in SkyPatternCatalog.all where !pattern.closed {
            let points = pattern.anchors.compactMap { map[$0] }.map(simd_normalize)
            XCTAssertEqual(points.count, pattern.anchors.count, pattern.name)
            for index in 1..<(points.count - 1) {
                // 折线在中间星处的「入向」与「出向」夹角应接近 180°；
                // 掉到 120° 以下说明这条路在折返，多半是锚星顺序排错了。
                let incoming = simd_normalize(points[index - 1] - points[index])
                let outgoing = simd_normalize(points[index + 1] - points[index])
                let angle = acos(Double(min(max(simd_dot(incoming, outgoing), -1), 1))) * 180 / .pi
                XCTAssertGreaterThan(
                    angle,
                    120,
                    "\(pattern.name) 在 \(pattern.anchors[index]) 处折返，锚星顺序可能排错了"
                )
            }
        }
    }

    /// 顶栏兜底不加角距门槛，依据是「6 等星表把全天盖满」。
    /// 这条测试就是那份依据：均匀撒 700 个方向，最远的一个也要在 7.4° 内找到成员星。
    func testNearestStarCoversTheWholeSky() throws {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        let members = catalog.stars.filter { !$0.constellation.isEmpty }
        XCTAssertGreaterThan(members.count, 2000)

        var worst = 0.0
        let samples = 700
        for index in 0..<samples {
            let y = 1 - 2 * (Double(index) + 0.5) / Double(samples)
            let radius = (1 - y * y).squareRoot()
            let theta = Double(index) * Double.pi * (3 - 5.0.squareRoot())
            let direction = SIMD3<Float>(
                Float(radius * cos(theta)),
                Float(y),
                Float(radius * sin(theta))
            )
            let region = ConstellationInfo.nearest(to: direction, in: members)
            XCTAssertNotNil(region, "这个方向找不到任何天区")
            worst = max(worst, region?.distance ?? 180)
        }
        XCTAssertLessThanOrEqual(
            worst,
            ConstellationInfo.worstNearestStarDegrees + 0.5,
            String(format: "全天覆盖变差，最远 %.1f°", worst)
        )
    }
}

final class SkyPerformanceProbeTests: XCTestCase {
    func testSamplerAveragesAndFindsWorstFrame() {
        var sampler = FrameRateSampler(window: 10, hitchThreshold: 1.0 / 30.0)
        for _ in 0..<8 { sampler.append(1.0 / 60.0) }
        sampler.append(1.0 / 20.0)
        XCTAssertEqual(sampler.sampleCount, 9)
        XCTAssertEqual(sampler.minimumFPS, 20, accuracy: 0.001)
        XCTAssertEqual(sampler.hitchCount, 1)
        XCTAssertEqual(sampler.hitchRatio, 1.0 / 9, accuracy: 0.0001)
        XCTAssertEqual(sampler.averageFPS, 9 / (8 / 60.0 + 0.05), accuracy: 0.01)
    }

    func testSamplerKeepsOnlyTheWindow() {
        var sampler = FrameRateSampler(window: 5)
        for index in 0..<12 { sampler.append(Double(index + 1) / 1000) }
        XCTAssertEqual(sampler.sampleCount, 5)
        XCTAssertEqual(sampler.averageFPS, 5 / (50.0 / 1000), accuracy: 0.01)
    }

    func testSamplerIgnoresNonPositiveDeltas() {
        var sampler = FrameRateSampler()
        sampler.append(0)
        sampler.append(-1)
        XCTAssertEqual(sampler.sampleCount, 0)
        XCTAssertEqual(sampler.averageFPS, 0)
        XCTAssertEqual(sampler.minimumFPS, 0)
        XCTAssertEqual(sampler.hitchRatio, 0)
    }

    func testProbeSummaryLineIsCompact() {
        var summary = ProbeSummary()
        summary.fps = 58.4
        summary.minimumFPS = 41.2
        summary.hitches = 2
        XCTAssertEqual(summary.fpsOnlyLine, "58fps · min 41 · 卡顿 2")
    }

    func testLayerAndFPSProbeSwitches() {
        XCTAssertTrue(LaunchMode.allLayersEnabled(environment: ["SPACEWALKER_LAYERS": "1"]))
        XCTAssertFalse(LaunchMode.allLayersEnabled(environment: ["SPACEWALKER_LAYERS": "0"]))
        XCTAssertFalse(LaunchMode.allLayersEnabled(environment: [:]))

        // 日志 Debug 默认开，0 是唯一的总闸；HUD 必须显式打开，免得污染截图。
        XCTAssertTrue(LaunchMode.perfLogEnabled(environment: ["SPACEWALKER_FPS": "1"]))
        XCTAssertFalse(LaunchMode.perfLogEnabled(environment: ["SPACEWALKER_FPS": "0"]))
        #if DEBUG
        XCTAssertTrue(LaunchMode.perfLogEnabled(environment: [:]))
        #endif
        XCTAssertTrue(LaunchMode.fpsHUDEnabled(environment: ["SPACEWALKER_FPS": "1"]))
        XCTAssertFalse(LaunchMode.fpsHUDEnabled(environment: [:]))
    }
}

final class ConstellationCoverageTests: XCTestCase {
    private func positions() throws -> [String: SIMD3<Float>] {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        var result: [String: SIMD3<Float>] = [:]
        for star in catalog.stars where !star.key.isEmpty && result[star.key] == nil {
            result[star.key] = StarField.position(for: star)
        }
        return result
    }

    private func center(_ constellation: Constellation, in map: [String: SIMD3<Float>]) -> SIMD3<Float>? {
        let keys = Set(constellation.lines.flatMap { [$0.first, $0.second] })
        let points = keys.compactMap { map[$0] }
        guard !points.isEmpty else { return nil }
        let sum = points.reduce(SIMD3<Float>(0, 0, 0)) { $0 + simd_normalize($1) }
        guard simd_length(sum) > 0.001 else { return nil }
        return simd_normalize(sum)
    }

    private func degrees(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Double {
        acos(Double(min(max(simd_dot(a, b), -1), 1))) * 180 / .pi
    }

    func testCoversAllEightyEightConstellations() {
        XCTAssertEqual(Constellations.primary.count, 31)
        XCTAssertEqual(Constellations.extended.count, 57)
        XCTAssertEqual(Constellations.all.count, 88)
        XCTAssertEqual(Set(Constellations.all.map(\.abbreviation)).count, 88)
    }

    func testEveryConstellationResolves() throws {
        let map = try positions()
        for constellation in Constellations.all {
            XCTAssertFalse(constellation.lines.isEmpty, "\(constellation.name) 没有连线")
            let segments = Constellations.segments(positions: map, in: [constellation])
            XCTAssertEqual(
                segments.count,
                constellation.lines.count,
                "\(constellation.name) 有端点落在星表外，画出来会断线"
            )
        }
    }

    func testOfficialSkeletonIsDenserThanTheHandDrawnOne() throws {
        // 手工那 31 座平均 4.5 段，换官方骨架后平均 11 段以上：
        // 人马座从「壶身六边形」变成带弓的射手，全靠这层数据。
        let primary = Constellations.primary
        let detailed = primary.compactMap { Constellations.detailedLines[$0.abbreviation] }
        let average = Double(detailed.map(\.count).reduce(0, +)) / Double(detailed.count)
        XCTAssertGreaterThan(average, 9)

        let sagittarius = try XCTUnwrap(Constellations.all.first { $0.abbreviation == "Sgr" })
        XCTAssertGreaterThanOrEqual(sagittarius.lines.count, 20, "人马座该有茶壶 + 弓，不止壶身")
    }

    @MainActor
    func testEveryConstellationButTheTwoStarDogCanBeIdentified() throws {
        let map = try positions()
        var identified = 0
        for constellation in Constellations.all {
            let shape = ConstellationFigureBuilder.shape(
                key: constellation.abbreviation,
                rings: SkyScene.hitRings(for: constellation, positions: map)
            )
            guard let shape else {
                // 两点成不了面：小犬座（南河三 + 南河二）、猎犬座（常陈一 + 猎犬座 β）。
                XCTAssertTrue(
                    ["CMi", "CVn"].contains(constellation.abbreviation),
                    "\(constellation.name) 没有判定区域"
                )
                continue
            }
            XCTAssertLessThan(shape.radiusDegrees, 90, "\(constellation.name) 的判定区域过大")
            identified += 1
        }
        XCTAssertEqual(identified, 86)
    }

    func testEnclosingCenterBeatsCentroidOnAsymmetricShapes() throws {
        // 人马座骨架一头是弓、一头是马身，质心明显偏向星多的一侧。
        // 定位用的是最小覆盖圆圆心，必须比质心更居中，否则「看全」时总有一头出画。
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        let sgr = try XCTUnwrap(Constellations.all.first { $0.abbreviation == "Sgr" })
        let keys = Set(sgr.lines.flatMap { [$0.first, $0.second] })
        let directions = catalog.stars
            .filter { keys.contains($0.key) }
            .map(SkyPicker.direction(for:))
        XCTAssertGreaterThan(directions.count, 10)

        let center = try XCTUnwrap(SkyPicker.enclosingCenter(of: directions))
        let centroid = directions.reduce(SIMD3<Float>(0, 0, 0), +)
        func reach(_ vector: SIMD3<Float>) -> Double {
            directions.map { SkyPicker.offsetDegrees($0, vector) }.max() ?? 0
        }
        XCTAssertLessThan(reach(center), reach(centroid), "最小覆盖圆没有比质心更居中")
        XCTAssertLessThan(reach(center), 20, "人马座骨架半径不该超过 20°")
        XCTAssertEqual(simd_length(center), 1, accuracy: 0.001)
    }

    func testLepusIsAdjacentToCanisMajor() throws {
        let map = try positions()
        let lepus = try XCTUnwrap(Constellations.all.first { $0.abbreviation == "Lep" })
        let canis = try XCTUnwrap(Constellations.all.first { $0.abbreviation == "CMa" })
        XCTAssertEqual(lepus.name, "天兔座")
        XCTAssertGreaterThanOrEqual(lepus.lines.count, 8, "天兔座不该只有零星几段")

        // 大犬座卡片里写「紧追天兔」，两座在天上必须真的是邻居：
        // 超出 25° 就说明数据串座了，用户按这句话找过去会落空。
        let a = try XCTUnwrap(center(lepus, in: map))
        let b = try XCTUnwrap(center(canis, in: map))
        XCTAssertLessThan(degrees(a, b), 25, "天兔座与大犬座不该相隔这么远")
    }
}

final class ConstellationShapeNoteTests: XCTestCase {
    func testEveryConstellationSaysHowToRecognizeIt() {
        // 88 座全覆盖：南天暗座也写，实在没有图案就直说，
        // 免得用户举着手机在一片暗星里白找。
        for constellation in Constellations.all {
            let note = ConstellationShapeNote.note(for: constellation.abbreviation)
            XCTAssertNotNil(note, "\(constellation.name) 缺「怎么认」")
            guard let note else { continue }
            XCTAssertGreaterThan(note.count, 8, constellation.name)
            XCTAssertLessThan(note.count, 62, "\(constellation.name) 的说明太长，卡片放不下")
        }
        XCTAssertEqual(ConstellationShapeNote.notes.count, 88)
    }

    func testArtCoversEverythingExceptSerpens() {
        // 南船座拆成船底/船尾/船帆三座，共用同一张整船图；巨蛇座原库就没有单图。
        let missing = Constellations.all
            .filter { ConstellationArt.imageName(for: $0.abbreviation) == nil }
            .map(\.abbreviation)
        XCTAssertEqual(missing, ["Ser"], "缺插画的不该只剩巨蛇座")
    }

    func testUnknownConstellationHasNoNote() {
        XCTAssertNil(ConstellationShapeNote.note(for: "ZZZ"))
    }
}

@MainActor
final class SkyAimTests: XCTestCase {
    private func target() -> SIMD3<Float> {
        // 人马座中心，赤经 19h、赤纬 −25° 附近，不在天极，能验滚转。
        StarField.direction(rightAscensionHours: 19, declinationDegrees: -25)
    }

    func testAimCentersTheDirectionAndLeavesNoRoll() {
        let scene = SkyScene()
        let direction = target()
        let rig = try? XCTUnwrap(scene.aim(at: direction))
        XCTAssertNotNil(rig)

        // 视线落点就是目标方向。
        XCTAssertEqual(SkyPicker.offsetDegrees(scene.viewDirectionInField, direction), 0, accuracy: 0.01)

        // 没有滚转：世界正上方投影到相机坐标系里应当只有 +Y 分量。
        // 旧的 simd_quatf(from:to:) 走最短弧，这里会拿到一个随机的滚转角，
        // 定位过去整片天歪着，截图里看得很明显。
        let up = scene.root.orientation.act(SIMD3<Float>(0, 1, 0))
        XCTAssertEqual(up.x, 0, accuracy: 0.001)
        XCTAssertGreaterThan(up.y, 0)
    }

    func testAimRoundTripsWithDrag() {
        // 定位后接着拖动，不能弹回旧角度：返回的 rig 必须就是当前朝向。
        let scene = SkyScene()
        let direction = target()
        let rig = try? XCTUnwrap(scene.aim(at: direction))
        XCTAssertNotNil(rig)
        guard let rig else { return }
        XCTAssertEqual(rig.orientation, scene.root.orientation)

        scene.setSource(.manual)
        scene.apply(rig: rig)
        XCTAssertEqual(SkyPicker.offsetDegrees(scene.viewDirectionInField, direction), 0, accuracy: 0.01)
    }

    /// 手动态定位就落在手动；跟随时定位只写偏移（另见 SkyAttitudeFrameTests）。
    func testAimInManualStaysManual() {
        let scene = SkyScene()
        scene.setSource(.manual)
        _ = scene.aim(at: target())
        XCTAssertEqual(scene.source, .manual)
        let centered = simd_normalize(scene.viewDirectionInField)
        XCTAssertEqual(SkyPicker.offsetDegrees(centered, target()), 0, accuracy: 0.5)
    }

    func testAttitudeSourceIgnoresManualRig() {
        let scene = SkyScene()
        guard let rig = scene.aim(at: target()) else { return XCTFail("aim 失败") }
        scene.setSource(.attitude)
        scene.apply(rig: SkyRig(yaw: rig.yaw + 0.6, pitch: rig.pitch))
        XCTAssertEqual(scene.root.orientation, rig.orientation, "跟随姿态时手动的 rig 不该覆盖")
    }

    func testAimRejectsZeroLength() {
        let scene = SkyScene()
        XCTAssertNil(scene.aim(at: SIMD3<Float>(0, 0, 0)))
    }
}

@MainActor
final class SkyFieldOfViewTests: XCTestCase {
    func testClampsToSupportedRange() {
        let scene = SkyScene()
        XCTAssertEqual(scene.fieldOfView, SkyScene.defaultFieldOfView)

        scene.setFieldOfView(2)
        XCTAssertEqual(scene.fieldOfView, SkyScene.minFieldOfView, "再小就只剩几颗星，没有意义")

        scene.setFieldOfView(400)
        XCTAssertEqual(scene.fieldOfView, SkyScene.maxFieldOfView)
        XCTAssertGreaterThan(SkyScene.minFieldOfView, 0)
        XCTAssertLessThan(SkyScene.minFieldOfView, SkyScene.maxFieldOfView)
    }

    func testIgnoresSubDegreeJitter() {
        let scene = SkyScene()
        let before = scene.fieldOfView
        scene.setFieldOfView(before + 0.01)
        XCTAssertEqual(scene.fieldOfView, before, "捏合手势每帧都会报值，零点几度不该重建 mesh")
    }

    func testRotationKeepsAngularScale() {
        // 竖屏 402×778、横屏 874×402。转屏若不改视场，同一片天会缩成一半；
        // 按高度比例缩放后每点对应的角度不变，星座看起来一样大，只是两边更空。
        let scene = SkyScene()
        scene.resize(CGSize(width: 402, height: 778))
        XCTAssertEqual(scene.fieldOfView, SkyScene.defaultFieldOfView)

        scene.resize(CGSize(width: 874, height: 402))
        XCTAssertEqual(scene.fieldOfView, 60 * 402 / 778, accuracy: 0.1)
        XCTAssertEqual(scene.baseFieldOfView, 60 * 402 / 778, accuracy: 0.1, "横屏双击该回到 31°，不是 60°")

        let portraitScale = 60.0 / 778
        let landscapeScale = Double(scene.fieldOfView) / 402
        XCTAssertEqual(portraitScale, landscapeScale, accuracy: 0.002, "每点对应角度变了，就是「横过来缩水」")

        scene.resize(CGSize(width: 402, height: 778))
        XCTAssertEqual(scene.fieldOfView, SkyScene.defaultFieldOfView, accuracy: 0.2, "转回去要回到原视场")
        XCTAssertEqual(scene.baseFieldOfView, SkyScene.defaultFieldOfView, accuracy: 0.2, "双击复位的基准也要跟着回来")
    }

    func testSameOrientationResizeDoesNotTouchFieldOfView() {
        // 分屏、来电横幅这类高度变化不该改视场，否则每变一次都缩一点。
        let scene = SkyScene()
        scene.resize(CGSize(width: 402, height: 778))
        scene.setFieldOfView(45)
        scene.resize(CGSize(width: 402, height: 740))
        XCTAssertEqual(scene.fieldOfView, 45, accuracy: 0.01)
    }

    func testAnyFieldOfViewFitsTheSagittariusSpan() throws {
        // 人马座跨 35°。竖屏默认 60° 垂直视场对应的水平只有 28°，
        // 所以必须靠拉远到 95° 或转横屏——这条测试钉住「默认装不下」这个事实，
        // 有人把默认视场改小了要能立刻发现。
        func horizontalFieldOfView(_ vertical: Double, width: Double = 393, height: Double = 852) -> Double {
            let halfVertical = vertical / 2 * .pi / 180
            return 2 * atan(tan(halfVertical) * width / height) * 180 / .pi
        }
        XCTAssertLessThan(horizontalFieldOfView(Double(SkyScene.defaultFieldOfView)), 35)
        XCTAssertGreaterThan(
            horizontalFieldOfView(Double(SkyScene.maxFieldOfView)),
            35,
            "最大视场也得装得下人马座，否则「看全」无从谈起"
        )

        // 横屏才是「看全」的正解：默认 60° 垂直视场，横过来水平就有 90°，
        // 75 座星座里最宽的也装得下，而且不用把视场拉到 95° 去牺牲细节。
        XCTAssertGreaterThan(
            horizontalFieldOfView(Double(SkyScene.defaultFieldOfView), width: 852, height: 393),
            80,
            "横屏默认视场装不下人马座，那就不是方向问题而是投影问题"
        )
    }

    /// 转屏能力写在 Info.plist 里，xcodegen 每次重写工程都会重新生成这个文件，
    /// 少写一条就静默退回竖屏锁死——用测试钉住。
    func testLandscapeIsDeclaredInInfoPlist() throws {
        let orientations = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String]
        )
        XCTAssertTrue(orientations.contains("UIInterfaceOrientationPortrait"))
        XCTAssertTrue(orientations.contains("UIInterfaceOrientationLandscapeLeft"))
        XCTAssertTrue(orientations.contains("UIInterfaceOrientationLandscapeRight"))
    }
}

@MainActor
final class SkyAttitudeFrameTests: XCTestCase {
    private func target() -> SIMD3<Float> {
        simd_normalize(SIMD3<Float>(0.3, 0.2, -1))
    }

    /// 跟随时跳转：目标要落在屏幕中心，而且输入源不能被切成手动。
    func testAimWhileFollowingCentersTargetWithoutLeavingFollow() {
        let scene = SkyScene()
        scene.setSource(.attitude)
        let upright = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        scene.setAttitude(upright)

        _ = scene.aim(at: target())

        XCTAssertEqual(scene.source, .attitude, "跟随时跳转不该切走输入源")
        let centered = simd_normalize(scene.viewDirectionInField)
        XCTAssertEqual(SkyPicker.offsetDegrees(centered, target()), 0, accuracy: 0.5)
    }

    /// 跳转偏移必须跟着姿态走：设备转一点，目标也跟着偏，而不是钉死在屏幕上。
    func testAimOffsetKeepsFollowingAttitude() {
        let scene = SkyScene()
        scene.setSource(.attitude)
        scene.setAttitude(simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))
        _ = scene.aim(at: target())
        let before = simd_normalize(scene.viewDirectionInField)

        let turned = simd_quatf(angle: 0.2, axis: SIMD3<Float>(0, 1, 0))
        scene.setAttitude(turned)
        let after = simd_normalize(scene.viewDirectionInField)

        XCTAssertGreaterThan(SkyPicker.offsetDegrees(before, after), 5, "姿态变化后视线应当跟着动")
    }

    /// 界面方向补偿：世界「上」必须落到画布的「上」，否则横屏左右多头会变成上下动。
    func testInterfaceRollMapsWorldUpOntoScreenUp() {
        let scene = SkyScene()
        scene.setSource(.attitude)
        scene.setAttitude(simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))
        let up = SIMD3<Float>(0, 1, 0)

        XCTAssertEqual(scene.root.orientation.act(up).y, 1, accuracy: 0.001, "竖屏：世界上就是画布上")

        scene.setInterfaceRoll(.pi / 2)
        let rolled = scene.root.orientation.act(up)
        XCTAssertEqual(abs(rolled.x), 1, accuracy: 0.001, "横屏：世界上应落到画布的长轴方向")
        XCTAssertEqual(rolled.y, 0, accuracy: 0.001)
    }
}
