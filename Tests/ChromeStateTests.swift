import XCTest

@testable import SpaceWalker

final class ChromeStateTests: XCTestCase {
    private func reduce(_ actions: [AppAction], from initial: AppState = AppState()) -> AppState {
        var state = initial
        let reducer = makeAppReducer()
        for action in actions {
            reducer(&state, action)
        }
        return state
    }

    private let routes: [AppRoute] = [.sky, .solarSystem, .tiangong]

    func testEveryModuleHasExactlyOnePrimaryAction() {
        var ids: Set<ChromePrimaryID> = []
        for route in routes {
            let chrome = ChromeState.derive(route: route)
            XCTAssertFalse(chrome.primaryAction.title.isEmpty)
            ids.insert(chrome.primaryAction.id)
        }
        XCTAssertEqual(ids.count, 3)
    }

    func testPrimaryActionTitlesMatchDesignBaseline() {
        XCTAssertEqual(ChromeState.derive(route: .sky).primaryAction.title, "找星")
        XCTAssertEqual(ChromeState.derive(route: .solarSystem).primaryAction.title, "全览")
        XCTAssertEqual(ChromeState.derive(route: .tiangong).primaryAction.title, "开始拆解")
    }

    func testStatusLineIsReadOnlyAndNeverCarriesThePrimaryAction() {
        for route in routes {
            let chrome = ChromeState.derive(route: route)
            XCTAssertFalse(chrome.statusLine.title.isEmpty)
            XCTAssertFalse(chrome.statusLine.detail.isEmpty)
            XCTAssertNotEqual(chrome.statusLine.title, chrome.primaryAction.title)
        }
    }

    func testContextControlsAreAtMostThreeAndAllLabeled() {
        for route in routes {
            for mode in ChromeMode.allCases {
                let chrome = ChromeState.derive(route: route, mode: mode)
                XCTAssertLessThanOrEqual(chrome.contextControls.count, 3, "\(route)/\(mode)")
                XCTAssertTrue(chrome.contextControls.allSatisfy { !$0.title.isEmpty }, "\(route)/\(mode)")
            }
        }
    }

    func testPrimaryActionChangesWithSelectionAndMode() {
        let star = ChromeState.derive(route: .sky, mode: .card, selection: .star("织女星"))
        XCTAssertEqual(star.primaryAction.title, "定位")

        let module = ChromeState.derive(route: .tiangong, mode: .card, selection: .module(.lab))
        XCTAssertEqual(module.primaryAction.title, "分离")

        let separated = ChromeState.derive(
            route: .tiangong,
            mode: .card,
            selection: .module(.lab),
            separation: ["lab"]
        )
        XCTAssertEqual(separated.primaryAction.title, "装回")

        let cutaway = ChromeState.derive(route: .tiangong, mode: .cutaway)
        XCTAssertEqual(cutaway.primaryAction.title, "退出剖面")

        let reentry = ChromeState.derive(route: .tiangong, mode: .reentry)
        XCTAssertEqual(reentry.primaryAction.title, "跳过")
    }

    func testReducerRecomputesChromeOnSelectionAndMode() {
        let selected = reduce([
            .route(.tiangong),
            .chrome(.select(.module(.lab))),
            .chrome(.setMode(.card)),
            .chrome(.setSeparation(["lab"]))
        ])
        XCTAssertEqual(selected.chrome.mode, .card)
        XCTAssertEqual(selected.chrome.selection, .module(.lab))
        XCTAssertEqual(selected.chrome.primaryAction.title, "装回")
        XCTAssertEqual(selected.chrome.tabs.map(\.isSelected), [false, false, true])
    }

    func testRouteChangeResetsModeAndSelection() {
        let state = reduce([
            .chrome(.select(.star("织女星"))),
            .chrome(.setMode(.card)),
            .route(.tiangong)
        ])
        XCTAssertEqual(state.chrome.mode, .normal)
        XCTAssertNil(state.chrome.selection)
        XCTAssertEqual(state.chrome.primaryAction.title, "开始拆解")
    }

    func testNilSelectionProducesNoLabelsAndNoCard() {
        for route in routes {
            let chrome = ChromeState.derive(route: route)
            XCTAssertNil(chrome.selection)
            XCTAssertTrue(chrome.visibleLabels.isEmpty)
            XCTAssertNil(chrome.infoCard)
        }
    }

    func testModuleSelectionProducesExactlyOneLabelAndOneCard() {
        let chrome = ChromeState.derive(route: .tiangong, mode: .card, selection: .module(.lab))
        XCTAssertEqual(chrome.visibleLabels, [ChromeLabel(id: "lab", title: "实验舱")])
        XCTAssertEqual(chrome.infoCard?.title, "实验舱")
        XCTAssertLessThanOrEqual(chrome.infoCard?.maxHeightRatio ?? 1, 0.32)
        XCTAssertEqual(chrome.infoCard?.placement, .abovePrimary)
    }

    func testStarAndBodySelectionsProduceCardsButNoModuleLabels() {
        let star = ChromeState.derive(route: .sky, mode: .card, selection: .star("织女星"))
        XCTAssertTrue(star.visibleLabels.isEmpty)
        XCTAssertEqual(star.infoCard?.title, "织女星")

        let body = ChromeState.derive(route: .solarSystem, mode: .card, selection: .body(.saturn))
        XCTAssertTrue(body.visibleLabels.isEmpty)
        XCTAssertEqual(body.infoCard?.placement, .abovePrimary)
    }

    func testDismissCardClearsSelectionLabelsAndCard() {
        let opened = AppState(
            route: .tiangong,
            diagnosticsEnabled: false
        )
        let state = reduce([
            .chrome(.select(.module(.lab))),
            .chrome(.setMode(.card)),
            .chrome(.dismissCard)
        ], from: opened)
        XCTAssertNil(state.chrome.selection)
        XCTAssertTrue(state.chrome.visibleLabels.isEmpty)
        XCTAssertNil(state.chrome.infoCard)
        XCTAssertEqual(state.chrome.mode, .normal)
    }

    func testSetModePreservesSelectionDerivedContent() {
        let state = reduce([
            .chrome(.select(.module(.lab))),
            .chrome(.setMode(.card))
        ])
        XCTAssertEqual(state.chrome.visibleLabels.count, 1)
        XCTAssertNotNil(state.chrome.infoCard)
    }

    func testDefaultThemeIsDark() {
        XCTAssertEqual(AppState().chrome.theme, .dark)
    }

    func testSetThemePreservesRouteSelectionAndStructure() {
        let state = reduce([
            .route(.tiangong),
            .chrome(.select(.module(.lab))),
            .chrome(.setMode(.card)),
            .chrome(.setTheme(.light))
        ])
        XCTAssertEqual(state.chrome.theme, .light)
        XCTAssertEqual(state.chrome.route, .tiangong)
        XCTAssertEqual(state.chrome.selection, .module(.lab))
        XCTAssertEqual(state.chrome.primaryAction.title, "分离")
        XCTAssertEqual(state.chrome.tabs.map(\.isSelected), [false, false, true])
    }

    func testRouteChangePreservesTheme() {
        let state = reduce([.chrome(.setTheme(.light)), .route(.sky)])
        XCTAssertEqual(state.chrome.theme, .light)
    }

    func testTypographyUsesAtMostFourSizesAndMinimumEleven() {
        let sizes = [
            ChromeTokens.captionSize,
            ChromeTokens.labelSize,
            ChromeTokens.bodySize,
            ChromeTokens.primarySize,
            ChromeTokens.titleSize
        ]
        XCTAssertLessThanOrEqual(Set(sizes).count, 4)
        XCTAssertGreaterThanOrEqual(sizes.min() ?? 0, 11)
    }

    func testInfoCardHeightRatioIsAtMostThirtyTwoPercent() {
        XCTAssertLessThanOrEqual(ChromeTokens.infoCardMaxHeightRatio, 0.32)
        let card = ChromeState.derive(route: .sky, selection: .star("织女星")).infoCard
        XCTAssertEqual(card?.maxHeightRatio, ChromeTokens.infoCardMaxHeightRatio)
        XCTAssertEqual(card?.placement, .abovePrimary)
    }

    func testCutawayControlsExcludeUnimplementedInteriorLabels() {
        let chrome = ChromeState.derive(route: .tiangong, mode: .cutaway)
        XCTAssertEqual(chrome.contextControls.map(\.id), [.tiangongResetView])
    }

    func testDockingControlsExcludeRedundantHoldButton() {
        let chrome = ChromeState.derive(route: .tiangong, mode: .docking)
        XCTAssertEqual(chrome.contextControls.map(\.id), [.tiangongCoarse, .tiangongFine])
    }

    func testUserFacingChromeHasNoDebugStrings() {
        for route in routes {
            for mode in ChromeMode.allCases {
                let chrome = ChromeState.derive(route: route, mode: mode)
                let text = [chrome.statusLine.title, chrome.statusLine.detail, chrome.primaryAction.title]
                    + chrome.contextControls.map(\.title)
                for line in text {
                    XCTAssertFalse(line.localizedCaseInsensitiveContains("fps"), line)
                    XCTAssertFalse(line.localizedCaseInsensitiveContains("pick"), line)
                    XCTAssertFalse(line.contains("坐标系"), line)
                }
            }
        }
    }
}
