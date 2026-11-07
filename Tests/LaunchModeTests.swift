import XCTest

@testable import SpaceWalker

final class LaunchModeTests: XCTestCase {
    func testDefaultRouteIsSolarSystem() {
        XCTAssertEqual(LaunchMode.initialRoute(environment: [:]), .solarSystem)
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
