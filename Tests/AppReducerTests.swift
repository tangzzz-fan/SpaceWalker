import XCTest

@testable import SpaceWalker

final class AppReducerTests: XCTestCase {
    private func reduce(_ actions: [AppAction], from initial: AppState = AppState()) -> AppState {
        var state = initial
        let reducer = makeAppReducer()
        for action in actions {
            reducer(&state, action)
        }
        return state
    }

    func testFlagsLoadedUpdatesState() {
        let state = reduce([.flagsLoaded(FeatureFlags(cultureEnabled: false, deepEnabled: true))])
        XCTAssertFalse(state.flags.cultureEnabled)
        XCTAssertTrue(state.flags.deepEnabled)
    }

    func testRouteChanges() {
        XCTAssertEqual(reduce([.route(.sky)]).route, .sky)
        XCTAssertEqual(reduce([.route(.solarSystem)]).route, .solarSystem)
    }

    func testAppStartedKeepsRoute() {
        let state = reduce([.appStarted], from: AppState(route: .sky))
        XCTAssertEqual(state.route, .sky)
    }

    func testDefaultChromeIsSkyWithThreeLabeledTabs() {
        let state = AppState()
        XCTAssertEqual(state.route, .sky)
        XCTAssertEqual(state.chrome.route, .sky)
        XCTAssertEqual(state.chrome.tabs.map(\.title), ["星图", "太阳系", "天宫一号"])
        XCTAssertEqual(state.chrome.tabs.map(\.route), [.sky, .solarSystem, .tiangong])
        XCTAssertEqual(state.chrome.tabs.map(\.isSelected), [true, false, false])
    }

    func testRouteActionRecomputesChrome() {
        let state = reduce([.route(.tiangong)])
        XCTAssertEqual(state.route, .tiangong)
        XCTAssertEqual(state.chrome.route, .tiangong)
        XCTAssertEqual(state.chrome.tabs.map(\.isSelected), [false, false, true])
        XCTAssertEqual(state.chrome.tabs.count, 3)
    }

    func testAppStartedDoesNotDesyncChrome() {
        let state = reduce([.appStarted], from: AppState(route: .tiangong))
        XCTAssertEqual(state.chrome.tabs.map(\.isSelected), [false, false, true])
        XCTAssertEqual(state.chrome.route, state.route)
    }

    func testDefaultDebugOverlayIsOff() {
        let chrome = AppState().chrome
        XCTAssertEqual(chrome.debugOverlay, .off)
        XCTAssertFalse(chrome.diagnosticsVisible)
    }

    func testToggleDiagnosticsOpensPanelWithoutLeakingOverlayToMainUI() {
        let opened = reduce([.chrome(.toggleDiagnostics)])
        XCTAssertTrue(opened.chrome.diagnosticsVisible)
        XCTAssertEqual(opened.chrome.debugOverlay, .off)
        let closed = reduce([.chrome(.toggleDiagnostics)], from: opened)
        XCTAssertFalse(closed.chrome.diagnosticsVisible)
    }

    func testRouteChangeClosesDiagnosticsPanel() {
        let state = reduce([.chrome(.toggleDiagnostics), .route(.tiangong)])
        XCTAssertEqual(state.chrome.route, .tiangong)
        XCTAssertFalse(state.chrome.diagnosticsVisible)
    }

    // MARK: - 083/084 chrome 派生入参

    func testSetTonightUpdatesSelectionAndStatus() {
        let state = reduce([.chrome(.setTonight(true))])
        XCTAssertEqual(state.chrome.contextControls.first { $0.id == .skyTonight }?.isSelected, true)
        XCTAssertEqual(state.chrome.statusLine.detail, "今夜此刻 · 时间已对齐")

        let off = reduce([.chrome(.setTonight(false))], from: state)
        XCTAssertEqual(off.chrome.contextControls.first { $0.id == .skyTonight }?.isSelected, false)
        XCTAssertEqual(off.chrome.statusLine.detail, "姿态跟随 · 转动手机环顾")
    }

    func testSetReentryUnlockedUpdatesControl() {
        let state = reduce([.route(.tiangong), .chrome(.setReentryUnlocked(true))])
        XCTAssertEqual(state.chrome.contextControls.first { $0.id == .tiangongReentry }?.isEnabled, true)
    }

    func testSetDockingFineUpdatesHighlight() {
        let state = reduce([
            .route(.tiangong),
            .chrome(.setMode(.docking)),
            .chrome(.setDockingFine(true))
        ])
        XCTAssertEqual(state.chrome.contextControls.first { $0.id == .tiangongFine }?.isSelected, true)
        XCTAssertEqual(state.chrome.contextControls.first { $0.id == .tiangongCoarse }?.isSelected, false)
    }

    func testModeChangePreservesTonightAndReentryFlags() {
        let state = reduce([
            .chrome(.setTonight(true)),
            .chrome(.setReentryUnlocked(true)),
            .chrome(.select(.star("织女星"))),
            .chrome(.setMode(.card))
        ])
        XCTAssertEqual(state.chrome.contextControls.first { $0.id == .skyTonight }?.isSelected, true)

        let tiangong = reduce([.route(.tiangong)], from: state)
        XCTAssertEqual(
            tiangong.chrome.contextControls.first { $0.id == .tiangongReentry }?.isEnabled, true
        )
    }

    func testSetStatusStillOverridesDetailAfterDerive() {
        let state = reduce([
            .chrome(.setTonight(true)),
            .chrome(.setStatus("自定义状态"))
        ])
        XCTAssertEqual(state.chrome.statusLine.detail, "自定义状态")
    }
}
