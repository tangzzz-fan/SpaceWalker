import XCTest

@testable import SpaceWalker

@MainActor
final class CultureLayerTests: XCTestCase {
    private func reduce(_ actions: [AppAction], from initial: AppState = AppState()) -> AppState {
        var state = initial
        let reducer = makeAppReducer()
        for action in actions {
            reducer(&state, action)
        }
        return state
    }

    func testCultureDefaultsOff() {
        XCTAssertFalse(FeatureFlags().cultureEnabled)
        XCTAssertFalse(AppFeature.contentCulture.typedDefaultValue)
        XCTAssertFalse(AppState().flags.cultureEnabled)
    }

    func testSkyHasOneTapCultureEntryReflectingState() {
        let off = ChromeState.derive(route: .sky)
        let control = off.contextControls.first { $0.id == .skyCulture }
        XCTAssertNotNil(control, "首屏必须有一次点击可达的文化入口")
        XCTAssertEqual(control?.title, "文化")
        XCTAssertEqual(control?.isSelected, false)

        let on = ChromeState.derive(route: .sky, cultureEnabled: true)
        XCTAssertEqual(on.contextControls.first { $0.id == .skyCulture }?.isSelected, true)
    }

    func testTogglingCultureViaFlagsUpdatesControl() {
        let on = reduce([.flagsLoaded(FeatureFlags(cultureEnabled: true, deepEnabled: false))])
        XCTAssertEqual(on.chrome.contextControls.first { $0.id == .skyCulture }?.isSelected, true)

        let off = reduce([.flagsLoaded(FeatureFlags(cultureEnabled: false, deepEnabled: false))], from: on)
        XCTAssertEqual(off.chrome.contextControls.first { $0.id == .skyCulture }?.isSelected, false)
    }

    func testCultureSurvivesLayerNavigation() {
        let state = reduce([
            .flagsLoaded(FeatureFlags(cultureEnabled: true, deepEnabled: false)),
            .descend(.solar),
            .ascend
        ])
        XCTAssertEqual(state.route, .sky)
        XCTAssertEqual(state.chrome.contextControls.first { $0.id == .skyCulture }?.isSelected, true)
    }

    func testAsterismAttentionIsIndependentOfCultureFlag() throws {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        let scene = SkyScene()
        scene.build(catalog: catalog)
        let shape = try XCTUnwrap(scene.constellationShapes.first { $0.key == "Ori" })
        let candidates = scene.candidates(along: shape.center)
        XCTAssertNotNil(candidates.asterism, "前提：猎户座中心落在星官里")

        let attention = candidates.forAttention(
            cultureEnabled: true,
            showsConstellations: false,
            showsPatterns: false
        )
        XCTAssertNotNil(attention.asterism, "星官属天文主线，不随演义文化开关关闭")
    }

    func testFengshenLinesExistInDataButGateIsAtViewLayer() throws {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        let groups = SkyGroupIndex.groups(stars: catalog.stars)
        let withFengshen = groups.filter { !$0.fengshenTitles.isEmpty }
        XCTAssertFalse(withFengshen.isEmpty, "封神数据仍在，只是默认不显示")
        XCTAssertNotNil(withFengshen.first?.fengshenLine)
    }

    func testCultureToggleDoesNotTouchOtherFlagsOrSelection() {
        let state = reduce([
            .chrome(.select(.star("织女星"))),
            .chrome(.setMode(.card)),
            .flagsLoaded(FeatureFlags(cultureEnabled: true, deepEnabled: true))
        ])
        XCTAssertTrue(state.flags.deepEnabled)
        XCTAssertEqual(state.chrome.selection, .star("织女星"))
        XCTAssertEqual(state.chrome.mode, .card)
    }

    func testOtherRoutesHaveNoCultureControl() {
        for route: ScaleLevel in [.solar, .earthOrbit, .tiangong] {
            let chrome = ChromeState.derive(route: route, cultureEnabled: true)
            XCTAssertNil(chrome.contextControls.first { $0.id == .skyCulture }, "\(route)")
        }
    }
}