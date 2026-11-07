import XCTest

@testable import SpaceWalker

final class CapabilityMatrixTests: XCTestCase {
    private let requested = SessionPlan.m0

    func testAllCapabilitiesReportsFullMode() {
        let matrix = CapabilityMatrixBuilder.make(
            requested: requested,
            unavailability: SessionUnavailability()
        )
        XCTAssertEqual(matrix.mode, .full)
        XCTAssertTrue(matrix.reasons.isEmpty)
        XCTAssertTrue(matrix.canAnchorToPlanes)
        XCTAssertTrue(matrix.canHitRealSurfaces)
        XCTAssertNil(matrix.headline)
        XCTAssertEqual(matrix.placementStrategy, .surfaceHit)
    }

    func testNoCapabilitiesReportsDegradedWithAllReasons() {
        let matrix = CapabilityMatrixBuilder.make(
            requested: requested,
            unavailability: SessionUnavailability(
                anchors: [.world, .plane],
                sceneUnderstanding: [.collision, .occlusion, .shadow],
                cameraAuthorized: false
            )
        )
        XCTAssertEqual(matrix.mode, .degraded)
        XCTAssertEqual(
            Set(matrix.reasons),
            Set([
                .cameraUnauthorized,
                .worldTrackingUnavailable,
                .planeAnchorUnavailable,
                .surfaceCollisionUnavailable,
                .occlusionUnavailable,
                .shadowUnavailable,
            ])
        )
        XCTAssertFalse(matrix.canAnchorToPlanes)
        XCTAssertFalse(matrix.canHitRealSurfaces)
        XCTAssertEqual(matrix.headline, "降级模式")
        XCTAssertEqual(matrix.placementStrategy, .unavailable)
    }

    func testPartialCapabilitiesKeepPlaneAnchoringWithDegradedPlacement() {
        let matrix = CapabilityMatrixBuilder.make(
            requested: requested,
            unavailability: SessionUnavailability(sceneUnderstanding: [.collision])
        )
        XCTAssertEqual(matrix.mode, .degraded)
        XCTAssertEqual(matrix.reasons, [.surfaceCollisionUnavailable])
        XCTAssertTrue(matrix.canAnchorToPlanes)
        XCTAssertFalse(matrix.canHitRealSurfaces)
        XCTAssertEqual(matrix.placementStrategy, .planeCenter)
        XCTAssertEqual(matrix.detail, "无表面命中")
    }

    func testUnrequestedCapabilitiesDoNotDegrade() {
        let minimal = SessionRequirements(anchors: [.world], sceneUnderstanding: [], camera: .back)
        let matrix = CapabilityMatrixBuilder.make(
            requested: minimal,
            unavailability: SessionUnavailability(
                anchors: [.plane],
                sceneUnderstanding: [.collision, .occlusion, .shadow]
            )
        )
        XCTAssertEqual(matrix.mode, .full)
        XCTAssertTrue(matrix.reasons.isEmpty)
    }

    func testOutcomeDrivesMatrix() {
        let outcome = SessionPlan.outcome(
            for: requested,
            unavailability: SessionUnavailability(sceneUnderstanding: [.occlusion])
        )
        let matrix = CapabilityMatrixBuilder.make(from: outcome)
        XCTAssertEqual(matrix.reasons, [.occlusionUnavailable])
        XCTAssertEqual(matrix.placementStrategy, .surfaceHit)
    }
}
