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

    func testUnknownModeKeepsSessionEntry() {
        let features = LaunchMode.enabledFeatures(environment: ["SPACEWALKER_MODE": "dome"])
        XCTAssertTrue(features.isEmpty)
    }
}
