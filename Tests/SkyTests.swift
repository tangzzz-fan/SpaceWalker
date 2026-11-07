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
        XCTAssertEqual(sixHours.z, 1, accuracy: 0.0001)
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
