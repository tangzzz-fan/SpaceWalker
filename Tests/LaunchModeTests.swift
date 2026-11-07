import XCTest

@testable import SpaceWalker

final class LaunchModeTests: XCTestCase {
    func testDefaultsToSessionEntry() {
        XCTAssertTrue(LaunchMode.enabledFeatures(environment: [:]).isEmpty)
    }

    func testPrototypeModeEnablesPrototype() {
        let features = LaunchMode.enabledFeatures(environment: ["SPACEWALKER_MODE": "prototype"])
        XCTAssertEqual(features, [.prototype])
    }

    func testAutoPlaceRequiresExplicitOptIn() {
        XCTAssertFalse(LaunchMode.autoPlaceEnabled(environment: [:]))
        XCTAssertTrue(LaunchMode.autoPlaceEnabled(environment: ["SPACEWALKER_AUTOPLACE": "1"]))
    }

    func testForcedDegradedIsOffByDefault() {
        XCTAssertEqual(
            LaunchMode.forcedUnavailability(environment: [:]),
            SessionUnavailability()
        )
    }

    func testForcedDegradedCollisionMarksSceneCapabilityMissing() {
        let forced = LaunchMode.forcedUnavailability(
            environment: ["SPACEWALKER_FORCE_DEGRADED": "collision"]
        )
        XCTAssertEqual(forced.sceneUnderstanding, [.collision])
        XCTAssertTrue(forced.cameraAuthorized)
    }

    func testForcedDegradedAllDropsPlanesAndScene() {
        let forced = LaunchMode.forcedUnavailability(
            environment: ["SPACEWALKER_FORCE_DEGRADED": "all"]
        )
        XCTAssertEqual(forced.anchors, [.plane])
        XCTAssertEqual(forced.sceneUnderstanding, [.collision, .occlusion, .shadow])
    }

    func testUnknownModeKeepsSessionEntry() {
        let features = LaunchMode.enabledFeatures(environment: ["SPACEWALKER_MODE": "dome"])
        XCTAssertTrue(features.isEmpty)
    }
}
