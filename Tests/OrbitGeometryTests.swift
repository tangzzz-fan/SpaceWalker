import XCTest
import simd
@testable import SpaceWalker

final class OrbitGeometryTests: XCTestCase {
    func testTorusVertexAndIndexCounts() {
        let data = OrbitRing.torus(majorRadius: 1, minorRadius: 0.1, majorSegments: 32, minorSegments: 6)
        XCTAssertEqual(data.positions.count, 32 * 6)
        XCTAssertEqual(data.normals.count, 32 * 6)
        XCTAssertEqual(data.indices.count, 32 * 6 * 6)
    }

    func testTorusNormalsAreUnitLength() {
        let data = OrbitRing.torus(majorRadius: 2, minorRadius: 0.05, majorSegments: 16, minorSegments: 5)
        for normal in data.normals {
            XCTAssertEqual(simd_length(normal), 1, accuracy: 0.001)
        }
    }

    func testTorusStaysWithinTubeBand() {
        let major: Float = 3
        let minor: Float = 0.2
        let data = OrbitRing.torus(majorRadius: major, minorRadius: minor, majorSegments: 24, minorSegments: 6)
        for position in data.positions {
            XCTAssertLessThanOrEqual(abs(position.y), minor + 0.001)
            let radial = (position.x * position.x + position.z * position.z).squareRoot()
            XCTAssertGreaterThanOrEqual(radial, major - minor - 0.001)
            XCTAssertLessThanOrEqual(radial, major + minor + 0.001)
        }
    }

    func testIndicesStayInBounds() {
        let data = OrbitRing.torus(majorRadius: 1, minorRadius: 0.05, majorSegments: 8, minorSegments: 4)
        let upperBound = UInt32(data.positions.count)
        XCTAssertTrue(data.indices.allSatisfy { $0 < upperBound })
    }
}

final class OrbitRigTests: XCTestCase {
    func testCameraSitsAtConfiguredDistance() {
        var rig = OrbitRig()
        rig.distance = 12
        XCTAssertEqual(simd_length(rig.cameraPosition()), 12, accuracy: 0.001)
    }

    func testPitchIsClamped() {
        var rig = OrbitRig()
        rig.rotate(deltaX: 0, deltaY: 10_000)
        XCTAssertEqual(rig.pitch, OrbitRig.pitchRange.upperBound, accuracy: 0.0001)
        rig.rotate(deltaX: 0, deltaY: -10_000)
        XCTAssertEqual(rig.pitch, OrbitRig.pitchRange.lowerBound, accuracy: 0.0001)
    }

    func testDollyIsClamped() {
        var rig = OrbitRig()
        rig.dolly(scale: 0.0001)
        XCTAssertEqual(rig.distance, OrbitRig.distanceRange.upperBound, accuracy: 0.0001)
        rig.dolly(scale: 10_000)
        XCTAssertEqual(rig.distance, OrbitRig.distanceRange.lowerBound, accuracy: 0.0001)
    }

    func testHorizontalDragChangesYaw() {
        var rig = OrbitRig()
        let initial = rig.yaw
        rig.rotate(deltaX: 100, deltaY: 0)
        XCTAssertNotEqual(rig.yaw, initial)
        XCTAssertEqual(rig.pitch, OrbitRig().pitch, accuracy: 0.0001)
    }

    func testNonPositiveScaleDoesNotMoveCamera() {
        var rig = OrbitRig()
        let before = rig.distance
        rig.dolly(scale: 0)
        XCTAssertEqual(rig.distance, before)
    }
}
