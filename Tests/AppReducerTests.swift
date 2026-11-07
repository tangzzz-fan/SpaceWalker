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
}
