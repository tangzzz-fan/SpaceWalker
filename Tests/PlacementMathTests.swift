import XCTest
import simd

@testable import SpaceWalker

final class PlacementMathTests: XCTestCase {
    func testSurfaceNormalNormalizes() {
        let normal = PlacementMath.surfaceNormal(SIMD3(0, 4, 0))
        XCTAssertEqual(normal.y, 1, accuracy: 0.0001)
    }

    func testSurfaceNormalFlipsDownwardNormals() {
        let normal = PlacementMath.surfaceNormal(SIMD3(0, -1, 0))
        XCTAssertEqual(normal.y, 1, accuracy: 0.0001)
    }

    func testSurfaceNormalFallsBackToUpForDegenerateInput() {
        XCTAssertEqual(PlacementMath.surfaceNormal(.zero), SIMD3(0, 1, 0))
    }

    func testSnappedCenterPutsBottomOnSurface() {
        let center = PlacementMath.snappedCenter(
            hit: SIMD3(0.2, 0.75, -0.4),
            normal: SIMD3(0, 1, 0),
            height: 0.08
        )
        XCTAssertEqual(center.y, 0.79, accuracy: 0.0001)
        XCTAssertEqual(center.x, 0.2, accuracy: 0.0001)
        XCTAssertEqual(center.z, -0.4, accuracy: 0.0001)
    }

    func testOrientationKeepsUpAlignedWithNormal() {
        let orientation = PlacementMath.orientation(normal: SIMD3(0, 1, 0))
        let up = orientation.act(SIMD3(0, 1, 0))
        XCTAssertEqual(up.y, 1, accuracy: 0.0001)
    }

    func testOrientationRotatesOntoTiltedSurface() {
        let normal = simd_normalize(SIMD3<Float>(0.6, 0.8, 0))
        let orientation = PlacementMath.orientation(normal: normal)
        let up = orientation.act(SIMD3(0, 1, 0))
        XCTAssertEqual(up.x, normal.x, accuracy: 0.0001)
        XCTAssertEqual(up.y, normal.y, accuracy: 0.0001)
    }

    func testDriftIsEuclideanDistance() {
        let drift = PlacementMath.drift(from: .zero, to: SIMD3(0.03, 0.04, 0))
        XCTAssertEqual(drift, 0.05, accuracy: 0.0001)
    }

    func testDriftThresholdBoundaryIsInclusive() {
        XCTAssertFalse(PlacementMath.exceedsDrift(0.2))
        XCTAssertTrue(PlacementMath.exceedsDrift(0.2001))
    }

    func testReplacePromptNeedsFiveSecondsWithoutSurface() {
        XCTAssertFalse(PlacementRules.shouldPromptReplace(secondsSinceSurfaceHit: 4.9))
        XCTAssertTrue(PlacementRules.shouldPromptReplace(secondsSinceSurfaceHit: 5))
    }
}
