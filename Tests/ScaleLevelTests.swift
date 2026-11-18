import XCTest

@testable import SpaceWalker

final class ScaleLevelTests: XCTestCase {
    private func reduce(_ actions: [AppAction], from initial: AppState = AppState()) -> AppState {
        var state = initial
        let reducer = makeAppReducer()
        for action in actions {
            reducer(&state, action)
        }
        return state
    }

    func testFourLevelsInScaleOrder() {
        XCTAssertEqual(ScaleLevel.allCases, [.sky, .solar, .earthOrbit, .tiangong])
        XCTAssertEqual(ScaleLevel.allCases.map(\.depth), [0, 1, 2, 3])
    }

    func testDescriptorTableCoversEveryLevelExactlyOnce() {
        XCTAssertEqual(Set(ScaleLevel.descriptors.keys), Set(ScaleLevel.allCases))
        for level in ScaleLevel.allCases {
            XCTAssertFalse(level.title.isEmpty)
            XCTAssertFalse(level.question.isEmpty)
            XCTAssertFalse(level.rulerText.isEmpty)
            XCTAssertGreaterThan(level.representativeMeters, 0)
            XCTAssertTrue(level.rulerRangeMeters.contains(level.representativeMeters), "\(level)")
        }
    }

    func testRepresentativeScalesStrictlyDecrease() {
        let values = ScaleLevel.allCases.map(\.representativeMeters)
        for (a, b) in zip(values, values.dropFirst()) {
            XCTAssertGreaterThan(a, b)
            XCTAssertGreaterThan(a / b, 100, "相邻层至少差两个数量级")
        }
    }

    func testHandoffRigsStayInsideOrbitRigLimits() {
        for level in ScaleLevel.allCases {
            let rig = level.handoffRig
            XCTAssertTrue(OrbitRig.distanceRange.contains(rig.distance), "\(level)")
            XCTAssertTrue(OrbitRig.pitchRange.contains(rig.pitch), "\(level)")
        }
    }

    func testDescendOnlyAcceptsNextLevel() {
        XCTAssertTrue(ScaleLevel.sky.canDescend(to: .solar))
        XCTAssertFalse(ScaleLevel.sky.canDescend(to: .earthOrbit))
        XCTAssertFalse(ScaleLevel.sky.canDescend(to: .tiangong))
        XCTAssertFalse(ScaleLevel.sky.canDescend(to: .sky))
        XCTAssertFalse(ScaleLevel.tiangong.canDescend(to: .sky))
    }

    func testIllegalDescendIsRejectedWithoutStateChange() {
        let before = AppState()
        let after = reduce([.descend(.tiangong)], from: before)
        XCTAssertEqual(after.route, .sky)
        XCTAssertEqual(after.chrome.route, .sky)
        XCTAssertEqual(after.chrome, before.chrome)
    }

    func testDescendChainReachesTiangong() {
        let state = reduce([.descend(.solar), .descend(.earthOrbit), .descend(.tiangong)])
        XCTAssertEqual(state.route, .tiangong)
        XCTAssertEqual(state.chrome.tabs.map(\.isSelected), [false, false, false, true])
    }

    func testAscendWalksBackOneLevelAndStopsAtSky() {
        var state = reduce([.route(.tiangong)])
        let reducer = makeAppReducer()
        reducer(&state, .ascend)
        XCTAssertEqual(state.route, .earthOrbit)
        reducer(&state, .ascend)
        XCTAssertEqual(state.route, .solar)
        reducer(&state, .ascend)
        XCTAssertEqual(state.route, .sky)
        reducer(&state, .ascend)
        XCTAssertEqual(state.route, .sky)
    }

    func testRoundTripRestoresSelectionOfEveryLevel() {
        var state = AppState()
        let reducer = makeAppReducer()
        reducer(&state, .chrome(.select(.star("织女星"))))
        reducer(&state, .chrome(.setMode(.card)))
        reducer(&state, .descend(.solar))
        XCTAssertNil(state.chrome.selection)
        reducer(&state, .chrome(.select(.body(.saturn))))
        reducer(&state, .chrome(.setMode(.card)))
        reducer(&state, .descend(.earthOrbit))
        reducer(&state, .descend(.tiangong))
        reducer(&state, .chrome(.select(.module(.lab))))
        reducer(&state, .chrome(.setMode(.card)))

        reducer(&state, .ascend)
        XCTAssertEqual(state.route, .earthOrbit)
        XCTAssertNil(state.chrome.selection)
        reducer(&state, .ascend)
        XCTAssertEqual(state.route, .solar)
        XCTAssertEqual(state.chrome.selection, .body(.saturn))
        XCTAssertEqual(state.chrome.mode, .card)
        reducer(&state, .ascend)
        XCTAssertEqual(state.route, .sky)
        XCTAssertEqual(state.chrome.selection, .star("织女星"))
        XCTAssertEqual(state.chrome.mode, .card)
    }

    func testRoundTripThreeTimesKeepsChromeConsistent() {
        var state = AppState()
        let reducer = makeAppReducer()
        for _ in 0..<3 {
            reducer(&state, .descend(.solar))
            reducer(&state, .descend(.earthOrbit))
            reducer(&state, .descend(.tiangong))
            reducer(&state, .ascend)
            reducer(&state, .ascend)
            reducer(&state, .ascend)
            XCTAssertEqual(state.route, .sky)
            XCTAssertEqual(state.chrome.route, state.route)
            XCTAssertEqual(state.chrome.tabs.map(\.isSelected), [true, false, false, false])
        }
    }

    func testNavigationPreservesThemeAndReentryUnlock() {
        let state = reduce([
            .chrome(.setTheme(.light)),
            .chrome(.setReentryUnlocked(true)),
            .descend(.solar),
            .descend(.earthOrbit),
            .descend(.tiangong)
        ])
        XCTAssertEqual(state.chrome.theme, .light)
        XCTAssertEqual(
            state.chrome.contextControls.first { $0.id == .tiangongReentry }?.isEnabled, true
        )
    }

    func testRouteJumpAcrossLevelsIsAllowedForNavigation() {
        let state = reduce([.route(.tiangong)])
        XCTAssertEqual(state.route, .tiangong)
        let back = reduce([.route(.sky)], from: state)
        XCTAssertEqual(back.route, .sky)
    }

    func testRulerTextsComeFromSingleConstantTable() {
        XCTAssertEqual(ScaleLevel.sky.rulerText, "4–3000 光年")
        XCTAssertEqual(ScaleLevel.solar.rulerText, "0.4–30 AU")
        XCTAssertEqual(ScaleLevel.earthOrbit.rulerText, "350 km–38 万 km")
        XCTAssertEqual(ScaleLevel.tiangong.rulerText, "约 10 米")
        for level in ScaleLevel.allCases {
            XCTAssertEqual(level.rulerText, ScaleLevel.descriptors[level]?.rulerText)
            XCTAssertEqual(level.title, ScaleLevel.descriptors[level]?.title)
        }
        XCTAssertEqual(AppState().chrome.tabs.map(\.title), ScaleLevel.allCases.map(\.title))
    }

    func testRulerReadingIsMonotonicWithoutRebound() {
        let pairs: [(ScaleLevel, ScaleLevel)] = [
            (.sky, .solar), (.solar, .earthOrbit), (.earthOrbit, .tiangong),
            (.tiangong, .earthOrbit), (.earthOrbit, .solar), (.solar, .sky)
        ]
        for (from, to) in pairs {
            let readings = stride(from: 0.0, through: 1.0, by: 0.05).map {
                ScaleRuler.readingMeters(from: from, to: to, progress: $0)
            }
            let descending = from.representativeMeters > to.representativeMeters
            for (a, b) in zip(readings, readings.dropFirst()) {
                if descending {
                    XCTAssertLessThanOrEqual(b, a, "\(from)->\(to)")
                } else {
                    XCTAssertGreaterThanOrEqual(b, a, "\(from)->\(to)")
                }
            }
            XCTAssertEqual(readings.first ?? 0, from.representativeMeters, accuracy: from.representativeMeters * 1e-9)
            XCTAssertEqual(readings.last ?? 0, to.representativeMeters, accuracy: to.representativeMeters * 1e-9)
        }
    }

    func testRulerProgressIsClamped() {
        XCTAssertEqual(
            ScaleRuler.readingMeters(from: .sky, to: .solar, progress: -3),
            ScaleLevel.sky.representativeMeters,
            accuracy: 1
        )
        XCTAssertEqual(
            ScaleRuler.readingMeters(from: .sky, to: .solar, progress: 7),
            ScaleLevel.solar.representativeMeters,
            accuracy: 1
        )
    }

    func testEarthOrbitChromeIsDerivedNotBorrowed() {
        let chrome = ChromeState.derive(route: .earthOrbit)
        XCTAssertEqual(chrome.statusLine.title, "地月系")
        XCTAssertEqual(chrome.primaryAction.id, .earthOrbitOverview)
        XCTAssertEqual(chrome.contextControls.map(\.id), [.earthOrbitView])
    }

    func testLaunchModeParsesEveryLevel() {
        XCTAssertEqual(LaunchMode.initialRoute(environment: ["SPACEWALKER_MODE": "solar"]), .solar)
        XCTAssertEqual(LaunchMode.initialRoute(environment: ["SPACEWALKER_MODE": "solarSystem"]), .solar)
        XCTAssertEqual(LaunchMode.initialRoute(environment: ["SPACEWALKER_MODE": "earthOrbit"]), .earthOrbit)
        XCTAssertEqual(LaunchMode.initialRoute(environment: ["SPACEWALKER_MODE": "tiangong"]), .tiangong)
        XCTAssertEqual(LaunchMode.initialRoute(environment: ["SPACEWALKER_MODE": "nonsense"]), .sky)
    }
}