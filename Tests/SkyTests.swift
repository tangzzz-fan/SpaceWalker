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
        let names = Set(catalog.stars.map(\.name).filter { !$0.isEmpty })
        let missing = Constellations.referencedNames.subtracting(names)

        XCTAssertTrue(missing.isEmpty, "星座连线引用了星表里不存在的星名：\(missing.sorted())")
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
        XCTAssertTrue(drawn.subtracting(described).isEmpty, "缺少来头文案：\(drawn.subtracting(described).sorted())")
        XCTAssertTrue(described.subtracting(drawn).isEmpty, "来头文案没有对应星座：\(described.subtracting(drawn).sorted())")
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
    func testTwentyEightMansionsAreAllPresent() {
        XCTAssertEqual(FengshenInfo.table.count, 28)
        for symbol in TwentyEightMansions.groups {
            for mansion in symbol.mansions {
                XCTAssertNotNil(FengshenInfo.table[mansion], "\(mansion) 宿缺少封神名号")
            }
        }
    }

    func testEightMansionsBelongToWaterOrFireDepartment() {
        let assigned = FengshenInfo.table.values.filter { $0.department != nil }
        XCTAssertEqual(assigned.count, 8)
        let fire = assigned.filter { $0.department == "火部" }.map(\.mansion).sorted()
        let water = assigned.filter { $0.department == "水部" }.map(\.mansion).sorted()
        XCTAssertEqual(fire, ["室", "尾", "翼", "觜"])
        XCTAssertEqual(water, ["参", "壁", "箕", "轸"])
    }

    func testMansionLookupFromFullName() {
        XCTAssertEqual(FengshenInfo.entry(forMansion: "参宿")?.lord, "参水猿")
        XCTAssertEqual(FengshenInfo.entry(forMansion: "参宿")?.person, "孙祥")
        XCTAssertNil(FengshenInfo.entry(forMansion: "五车"))
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
        XCTAssertEqual(StarDisplay.make(for: dubhe).fengshenLine, "封神 北斗七星君")
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
            starNames: [], fengshenLord: nil, fengshenPerson: nil
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
