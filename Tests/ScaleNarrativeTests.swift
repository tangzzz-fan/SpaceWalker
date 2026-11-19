import XCTest
import simd

@testable import SpaceWalker

final class ScaleNarrativeTests: XCTestCase {
    private func reduce(_ actions: [SolarSystemAction]) -> SolarSystemState {
        var state = SolarSystemState()
        for action in actions {
            SolarSystemReducer.reduce(&state, action)
        }
        return state
    }

    func testEnterOverviewStartsPlaying() {
        let state = reduce([.enterOverview])
        XCTAssertTrue(state.narrative.isPlaying)
        XCTAssertEqual(state.narrative.phase, .playing)
        XCTAssertEqual(state.narrative.playCount, 1)
    }

    func testFinishReturnsToIdleScaleAndMarksPlayed() {
        let state = reduce([.enterOverview, .finishScaleNarrative])
        XCTAssertFalse(state.narrative.isPlaying)
        XCTAssertEqual(state.narrative.phase, .played)
    }

    func testRepeatedOverviewNeverReplays() {
        let state = reduce([
            .enterOverview, .finishScaleNarrative,
            .enterOverview, .enterOverview, .finishScaleNarrative,
        ])
        XCTAssertEqual(state.narrative.playCount, 1, "每次进入全览最多播一次，播过不再播")
        XCTAssertFalse(state.narrative.isPlaying)
    }

    func testEnterWhilePlayingDoesNotRestart() {
        let state = reduce([.enterOverview, .enterOverview])
        XCTAssertEqual(state.narrative.playCount, 1)
    }

    func testFinishWithoutPlayingIsNoOp() {
        let state = reduce([.finishScaleNarrative])
        XCTAssertEqual(state.narrative.phase, .idle)
        XCTAssertEqual(state.narrative.playCount, 0)
    }

    func testDurationIsAbout06Seconds() {
        XCTAssertEqual(ScaleNarrative.duration, 0.6, accuracy: 0.0001)
    }

    func testRulerTextMatchesADR() {
        XCTAssertEqual(ScaleNarrative.rulerText, "此刻行星直径 < 1 像素")
    }

    // MARK: - 真比例几何

    func testTrueScaleRadiusIsPhysical() {
        let earth = SolarSystem.body(.earth)!
        let expected = Float(12_756.0 / 2 / 149_597_870.7)
        XCTAssertEqual(SolarLayout.trueScaleRadius(for: earth), expected, accuracy: expected * 0.001)
    }

    func testTrueScalePlanetsAreSubPixelAtOverview() {
        // 默认全览机位 distance=12、fov=55°、屏幕高 852pt：
        // 所有行星直径 < 1px，太阳也 < 1px——「空」是真实陈述。
        let distance: Double = 12
        let screenHeight: Double = 852
        let focal = screenHeight / 2 / tan(55 * .pi / 360)
        for planet in SolarSystem.bodies {
            let diameterPixels = Double(SolarLayout.trueScaleRadius(for: planet)) * 2 * focal / distance
            XCTAssertLessThan(diameterPixels, 1, "\(planet.name) 真比例应 < 1 像素")
        }
    }

    func testTrueScaleFactorShrinksEveryBody() {
        for planet in SolarSystem.bodies {
            let factor = SolarLayout.trueScaleFactor(for: planet)
            XCTAssertGreaterThan(factor, 0)
            XCTAssertLessThan(factor, 0.02, "\(planet.name) 真比例至少缩到教学比例的 2% 以下")
        }
    }

    func testTrueScaleKeepsOrbitLayoutUntouched() {
        // 叙事只压球体，不压轨道：否则全览连轨道都看不见，陈述失去参照。
        let earth = SolarSystem.body(.earth)!
        XCTAssertEqual(SolarLayout.orbitRadius(for: earth), 1.0, accuracy: 0.0001)
        XCTAssertLessThan(SolarLayout.trueScaleRadius(for: earth), 0.0001)
    }

    // MARK: - reducer 接线

    func testOverviewActionShowsRulerTextInStatus() {
        var state = AppState(route: .solar)
        let reducer = makeAppReducer()
        reducer(&state, .space(.enterOverview))
        XCTAssertEqual(state.chrome.statusLine.detail, ScaleNarrative.rulerText)
    }

    func testFinishRestoresNormalStatus() {
        var state = AppState(route: .solar)
        let reducer = makeAppReducer()
        reducer(&state, .space(.enterOverview))
        reducer(&state, .space(.finishScaleNarrative))
        XCTAssertEqual(
            state.chrome.statusLine.detail,
            SolarSystemState.statusDetail(days: 0, isPaused: false, rate: 1)
        )
        XCTAssertFalse(state.space.narrative.isPlaying)
    }

    func testRepeatedOverviewDoesNotRewriteStatus() {
        var state = AppState(route: .solar)
        let reducer = makeAppReducer()
        reducer(&state, .space(.enterOverview))
        reducer(&state, .space(.finishScaleNarrative))
        let detail = state.chrome.statusLine.detail
        reducer(&state, .space(.enterOverview))
        XCTAssertEqual(state.chrome.statusLine.detail, detail, "播过之后全览不再改写状态行")
    }

    func testLaunchKeyTriggersNarrativeOnlyWhenSet() {
        XCTAssertFalse(LaunchMode.scaleNarrativeOnLaunch(environment: [:]))
        XCTAssertTrue(LaunchMode.scaleNarrativeOnLaunch(environment: ["SPACEWALKER_NARRATIVE": "1"]))
        XCTAssertFalse(LaunchMode.scaleNarrativeOnLaunch(environment: ["SPACEWALKER_NARRATIVE": "0"]))
    }

    func testNarrativeDurationOverrideIsDebugOnlyEvidenceKnob() {
        XCTAssertNil(LaunchMode.scaleNarrativeDuration(environment: [:]))
        #if DEBUG
        XCTAssertEqual(
            LaunchMode.scaleNarrativeDuration(environment: ["SPACEWALKER_NARRATIVE_SECONDS": "4"]),
            4
        )
        #endif
        XCTAssertEqual(ScaleNarrative.duration, 0.6, accuracy: 0.0001, "生产时长不被取证开关改变")
    }
}