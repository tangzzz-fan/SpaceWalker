import XCTest

@testable import SpaceWalker

final class SessionPlanTests: XCTestCase {
    func testM0RequiresWorldAndCameraOnBackLens() {
        XCTAssertEqual(SessionPlan.m0.anchors, [.world, .camera])
        XCTAssertTrue(SessionPlan.m0.sceneUnderstanding.isEmpty)
        XCTAssertEqual(SessionPlan.m0.camera, .back)
    }

    func testReducedDropsUnavailableAnchors() {
        let unavailable = SessionUnavailability(anchors: [.camera])
        let reduced = SessionPlan.reduced(SessionPlan.m0, by: unavailable)
        XCTAssertEqual(reduced.anchors, [.world])
    }

    func testOutcomeStaysUsableWithoutCameraAnchor() {
        let outcome = SessionPlan.outcome(
            for: SessionPlan.m0,
            unavailability: SessionUnavailability(anchors: [.camera])
        )
        XCTAssertTrue(outcome.isUsable)
    }

    func testOutcomeIsUnusableWithoutWorldTracking() {
        let outcome = SessionPlan.outcome(
            for: SessionPlan.m0,
            unavailability: SessionUnavailability(anchors: [.world])
        )
        XCTAssertFalse(outcome.isUsable)
    }

    func testOutcomeIsUnusableWithoutCameraAuthorization() {
        let outcome = SessionPlan.outcome(
            for: SessionPlan.m0,
            unavailability: SessionUnavailability(cameraAuthorized: false)
        )
        XCTAssertFalse(outcome.isUsable)
        XCTAssertFalse(outcome.unavailability.cameraAuthorized)
    }

    func testSceneUnderstandingIsSubtracted() {
        let requirements = SessionRequirements(
            anchors: [.world],
            sceneUnderstanding: [.shadow, .occlusion],
            camera: .back
        )
        let outcome = SessionPlan.outcome(
            for: requirements,
            unavailability: SessionUnavailability(sceneUnderstanding: [.occlusion])
        )
        XCTAssertEqual(outcome.requirements.sceneUnderstanding, [.shadow])
        XCTAssertTrue(outcome.isUsable)
    }
}
