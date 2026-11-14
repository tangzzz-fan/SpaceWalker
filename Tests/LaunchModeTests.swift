import XCTest

@testable import SpaceWalker

final class LaunchModeTests: XCTestCase {
    func testDefaultRouteIsSky() {
        XCTAssertEqual(LaunchMode.initialRoute(environment: [:]), .sky)
    }

    func testSkyRouteFromEnvironment() {
        XCTAssertEqual(LaunchMode.initialRoute(environment: ["SPACEWALKER_MODE": "sky"]), .sky)
    }

    func testPickProbeIsOffByDefault() {
        XCTAssertFalse(LaunchMode.pickProbeEnabled(environment: [:]))
        XCTAssertTrue(LaunchMode.pickProbeEnabled(environment: ["SPACEWALKER_PICKPROBE": "1"]))
    }

    func testFlagsOverrideReadsEnvironment() {
        XCTAssertEqual(AppFeature.contentDeep.overrideKey, "SPACEWALKER_FLAG_DEEP")
        XCTAssertEqual(AppFeature.contentCulture.overrideKey, "SPACEWALKER_FLAG_CULTURE")
    }
}
