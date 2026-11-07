import XCTest
import simd

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

    func testSelectShowsInfoCard() {
        let state = reduce([.prototype(.select)])
        XCTAssertTrue(state.prototype.isSelected)
        XCTAssertTrue(state.prototype.infoCardVisible)
    }

    func testDeselectHidesInfoCard() {
        let state = reduce([.prototype(.select), .prototype(.deselect)])
        XCTAssertFalse(state.prototype.isSelected)
        XCTAssertFalse(state.prototype.infoCardVisible)
    }

    func testMoveClampsToRadius() {
        let state = reduce([.prototype(.move(to: SIMD3(10, 2, 0)))])
        XCTAssertEqual(state.prototype.planetPosition.y, 0)
        XCTAssertEqual(
            simd_length(SIMD2(state.prototype.planetPosition.x, state.prototype.planetPosition.z)),
            PrototypeLogic.maxRadius,
            accuracy: 0.0001
        )
    }

    func testScaleClamps() {
        XCTAssertEqual(
            reduce([.prototype(.setScale(99))]).prototype.planetScale,
            PrototypeLogic.maxScale
        )
        XCTAssertEqual(
            reduce([.prototype(.setScale(0.01))]).prototype.planetScale,
            PrototypeLogic.minScale
        )
    }

    func testFlagsLoadedUpdatesState() {
        let state = reduce([.flagsLoaded(FeatureFlags(prototypeEnabled: false))])
        XCTAssertFalse(state.flags.prototypeEnabled)
    }

    func testResetKeepsPlacedPhase() {
        let state = reduce([
            .prototype(.anchored),
            .prototype(.select),
            .prototype(.reset),
        ])
        XCTAssertEqual(state.prototype.phase, .placed)
        XCTAssertFalse(state.prototype.isSelected)
        XCTAssertEqual(state.prototype.planetScale, 1)
    }
}
