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
        XCTAssertEqual(state.chrome.ladder.map(\.isSelected), [false, false, false, true])
    }

    func testAscendWalksBackOneLevelAndStopsAtSky() {
        var state = reduce([.descend(.solar), .descend(.earthOrbit), .descend(.tiangong)])
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
            XCTAssertEqual(state.chrome.ladder.map(\.isSelected), [true, false, false, false])
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

    func testRouteJumpUpIsAllowedButSkipDescendIsRejected() {
        let state = reduce([.descend(.solar), .descend(.earthOrbit), .descend(.tiangong)])
        XCTAssertEqual(state.route, .tiangong)
        let back = reduce([.route(.sky)], from: state)
        XCTAssertEqual(back.route, .sky)
        let skipped = reduce([.route(.tiangong)], from: AppState())
        XCTAssertEqual(skipped.route, .sky, "隔层下钻必须被拒绝")
        XCTAssertNil(skipped.transition)
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
        XCTAssertEqual(AppState().chrome.ladder.map(\.title), ScaleLevel.allCases.map(\.title))
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
// MARK: - 096 阶梯导航与常显尺子

final class ScaleLadderStateTests: XCTestCase {
    private func reduce(_ actions: [AppAction], from initial: AppState = AppState()) -> AppState {
        var state = initial
        let reducer = makeAppReducer()
        for action in actions {
            reducer(&state, action)
        }
        return state
    }

    func testLadderNodeStatesFollowNavigationRules() {
        let sky = ChromeLadderNode.nodes(for: .sky).map(\.state)
        XCTAssertEqual(sky, [.current, .reachable, .unreachable, .unreachable])
        let solar = ChromeLadderNode.nodes(for: .solar).map(\.state)
        XCTAssertEqual(solar, [.reachable, .current, .reachable, .unreachable])
        let earth = ChromeLadderNode.nodes(for: .earthOrbit).map(\.state)
        XCTAssertEqual(earth, [.reachable, .reachable, .current, .reachable])
        let tiangong = ChromeLadderNode.nodes(for: .tiangong).map(\.state)
        XCTAssertEqual(tiangong, [.reachable, .reachable, .reachable, .current])
    }

    func testUnreachableNodesAreDisabledAndCurrentIsSelected() {
        let nodes = ChromeLadderNode.nodes(for: .sky)
        XCTAssertEqual(nodes.map(\.isEnabled), [true, true, false, false])
        XCTAssertEqual(nodes.map(\.isSelected), [true, false, false, false])
        XCTAssertEqual(nodes.first?.title, "星图")
    }

    func testLegalNavigationEmitsTransitionRequest() {
        let state = reduce([.descend(.solar)])
        XCTAssertEqual(state.transition, ScaleTransitionRequest(from: .sky, to: .solar, token: 1))
        let up = reduce([.route(.sky)], from: state)
        XCTAssertEqual(up.transition, ScaleTransitionRequest(from: .solar, to: .sky, token: 2))
    }

    func testIllegalNavigationEmitsNoTransition() {
        let state = reduce([.route(.earthOrbit)])
        XCTAssertEqual(state.route, .sky)
        XCTAssertNil(state.transition)
        XCTAssertEqual(state.transitionToken, 0)
    }

    func testAscendToSkyShowsAttitudeNoticeExactlyOnce() {
        var state = reduce([.descend(.solar)])
        XCTAssertEqual(state.attitudeRestoreNoticeToken, 0)
        let reducer = makeAppReducer()
        reducer(&state, .ascend)
        XCTAssertEqual(state.attitudeRestoreNoticeToken, 1)
        XCTAssertTrue(state.hasShownAttitudeRestoreNotice)
        reducer(&state, .descend(.solar))
        reducer(&state, .ascend)
        XCTAssertEqual(state.attitudeRestoreNoticeToken, 1, "一次性提示不许重复")
    }

    func testDescendNeverShowsAttitudeNotice() {
        let state = reduce([.descend(.solar), .descend(.earthOrbit), .descend(.tiangong)])
        XCTAssertEqual(state.attitudeRestoreNoticeToken, 0)
        XCTAssertFalse(state.hasShownAttitudeRestoreNotice)
    }

    func testOverviewActionBumpsTokenWithoutMovingRoute() {
        let before = reduce([.descend(.solar)])
        let state = reduce([.overview, .overview], from: before)
        XCTAssertEqual(state.route, .solar)
        XCTAssertEqual(state.overviewToken, 2)
        XCTAssertEqual(state.transition, before.transition, "回全览不是切层，不发转场请求")
    }
}

final class ScaleRulerMathTests: XCTestCase {
    func testEaseInOutCubicEndpointsAndMidpoint() {
        XCTAssertEqual(ScaleRuler.easeInOutCubic(0), 0)
        XCTAssertEqual(ScaleRuler.easeInOutCubic(1), 1)
        XCTAssertEqual(ScaleRuler.easeInOutCubic(0.5), 0.5, accuracy: 1e-12)
        XCTAssertEqual(ScaleRuler.easeInOutCubic(-2), 0)
        XCTAssertEqual(ScaleRuler.easeInOutCubic(9), 1)
    }

    func testEaseInOutCubicIsMonotonic() {
        let values = stride(from: 0.0, through: 1.0, by: 0.01).map(ScaleRuler.easeInOutCubic)
        for (a, b) in zip(values, values.dropFirst()) {
            XCTAssertGreaterThanOrEqual(b, a)
        }
    }

    func testCubicEasedReadingStaysMonotonicAcrossEveryAdjacentPair() {
        let pairs: [(ScaleLevel, ScaleLevel)] = [
            (.sky, .solar), (.solar, .earthOrbit), (.earthOrbit, .tiangong),
            (.tiangong, .earthOrbit), (.earthOrbit, .solar), (.solar, .sky)
        ]
        for (from, to) in pairs {
            let readings = stride(from: 0.0, through: 1.0, by: 0.02).map { t in
                ScaleRuler.readingMeters(from: from, to: to, progress: ScaleRuler.easeInOutCubic(t))
            }
            let descending = from.representativeMeters > to.representativeMeters
            for (a, b) in zip(readings, readings.dropFirst()) {
                if descending {
                    XCTAssertLessThanOrEqual(b, a, "\(from)->\(to)")
                } else {
                    XCTAssertGreaterThanOrEqual(b, a, "\(from)->\(to)")
                }
            }
        }
    }

    func testReadingFromDisplayedMetersRestartsWithoutRebound() {
        let midway = ScaleRuler.readingMeters(from: .sky, to: .solar, progress: 0.4)
        let readings = stride(from: 0.0, through: 1.0, by: 0.05).map { t in
            ScaleRuler.readingMeters(
                fromMeters: midway,
                toMeters: ScaleLevel.sky.representativeMeters,
                progress: ScaleRuler.easeInOutCubic(t)
            )
        }
        XCTAssertEqual(readings.first ?? 0, midway, accuracy: midway * 1e-9)
        for (a, b) in zip(readings, readings.dropFirst()) {
            XCTAssertGreaterThanOrEqual(b, a, "中途反转必须从已显示值单调上行")
        }
    }

    func testTrackFractionsCoverDesignPositions() {
        XCTAssertEqual(ScaleRuler.trackFraction(meters: 1), 0, accuracy: 1e-9)
        XCTAssertEqual(ScaleRuler.trackFraction(meters: 1e20), 1, accuracy: 1e-9)
        XCTAssertEqual(ScaleRuler.trackFraction(meters: 1e10), 0.5, accuracy: 1e-9)
        let sky = ScaleRuler.trackRange(for: .sky)
        XCTAssertEqual(sky.lowerBound, 0.829, accuracy: 0.002)
        XCTAssertEqual(sky.upperBound, 0.973, accuracy: 0.002)
        let tiangong = ScaleRuler.trackRange(for: .tiangong)
        XCTAssertEqual(tiangong.lowerBound, 0.024, accuracy: 0.002)
        XCTAssertEqual(tiangong.upperBound, 0.051, accuracy: 0.002)
        for level in ScaleLevel.allCases {
            let range = ScaleRuler.trackRange(for: level)
            XCTAssertLessThan(range.lowerBound, range.upperBound)
            XCTAssertTrue((0.0...1.0).contains(range.lowerBound))
            XCTAssertTrue((0.0...1.0).contains(range.upperBound))
        }
    }

    func testReadingTextUsesStableScientificNotation() {
        XCTAssertEqual(ScaleRuler.readingText(meters: ScaleLevel.sky.representativeMeters), "10^19.0 m")
        XCTAssertEqual(ScaleRuler.readingText(meters: ScaleLevel.tiangong.representativeMeters), "10^1.0 m")
        XCTAssertEqual(ScaleRuler.readingText(meters: 0.2), "10^0.0 m")
    }
}
