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

    func testDiagnosticsAreOffByDefault() {
        let settings = LaunchMode.diagnostics(environment: [:])
        XCTAssertFalse(settings.fpsHUD)
        XCTAssertFalse(settings.pickProbe)
        XCTAssertFalse(settings.coordinateStatus)
        XCTAssertTrue(settings.overrides.isEmpty)
    }

    func testDiagnosticsCollectsEverySpacewalkerOverride() {
        let settings = LaunchMode.diagnostics(environment: [
            "SPACEWALKER_FPS": "1",
            "SPACEWALKER_PICKPROBE": "1",
            "SPACEWALKER_TG_CUTAWAY": "1",
            "SPACEWALKER_FLAG_DEEP": "1"
        ])
        XCTAssertTrue(settings.fpsHUD)
        XCTAssertTrue(settings.pickProbe)
        XCTAssertEqual(settings.overrides, [
            "SPACEWALKER_FLAG_DEEP=1",
            "SPACEWALKER_FPS=1",
            "SPACEWALKER_PICKPROBE=1",
            "SPACEWALKER_TG_CUTAWAY=1"
        ])
    }

    func testFeatureOverrideUsesInjectedEnvironment() {
        let environment = ["SPACEWALKER_FLAG_DEEP": "1"]
        XCTAssertEqual(AppFeature.contentDeep.override(environment: environment), true)
        XCTAssertNil(AppFeature.contentCulture.override(environment: environment))
        XCTAssertNil(AppFeature.contentDeep.override(environment: [:]))
    }

    func testEnvironmentIsInjectable() {
        XCTAssertEqual(LaunchMode.environment(["SPACEWALKER_MODE": "tiangong"]), ["SPACEWALKER_MODE": "tiangong"])
    }

    func testThemeIsInjectableForHeadlessEvidence() {
        XCTAssertEqual(LaunchMode.theme(environment: [:]), .dark)
        XCTAssertEqual(LaunchMode.theme(environment: ["SPACEWALKER_THEME": "light"]), .light)
        XCTAssertEqual(AppState(theme: .light).chrome.theme, .light)
    }

    func testDiagnosticsPanelCanBeOpenedForHeadlessEvidence() {
        XCTAssertFalse(LaunchMode.diagnosticsPanelOnLaunch(environment: [:]))
        XCTAssertTrue(LaunchMode.diagnosticsPanelOnLaunch(environment: ["SPACEWALKER_DIAGNOSTICS": "1"]))
        XCTAssertTrue(AppState(diagnosticsEnabled: true).chrome.diagnosticsVisible)
    }
}
