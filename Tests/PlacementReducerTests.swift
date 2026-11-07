import XCTest

@testable import SpaceWalker

final class PlacementReducerTests: XCTestCase {
    private func reduce(_ actions: [PlacementAction]) -> PlacementState {
        var state = PlacementState()
        for action in actions {
            PlacementReducer.reduce(&state, action)
        }
        return state
    }

    func testPlacedResetsDriftAndPrompt() {
        let state = reduce([
            .driftMeasured(0.3),
            .placed,
        ])
        XCTAssertTrue(state.isPlaced)
        XCTAssertFalse(state.needsReplace)
        XCTAssertEqual(state.driftMeters, 0)
    }

    func testDriftBeyondThresholdPromptsReplace() {
        let state = reduce([.placed, .driftMeasured(0.25)])
        XCTAssertTrue(state.needsReplace)
        XCTAssertEqual(state.driftMeters, 0.25, accuracy: 0.0001)
    }

    func testDriftWithinThresholdDoesNotPrompt() {
        let state = reduce([.placed, .driftMeasured(0.12)])
        XCTAssertFalse(state.needsReplace)
    }

    func testResetClearsEverything() {
        let state = reduce([.placed, .driftMeasured(0.4), .reset])
        XCTAssertFalse(state.isPlaced)
        XCTAssertFalse(state.needsReplace)
        XCTAssertEqual(state.driftMeters, 0)
    }

    func testDriftLineFormatsCentimeters() {
        let state = reduce([.placed, .driftMeasured(0.123)])
        XCTAssertEqual(state.driftLine, "漂移 12.3 cm")
    }
}
