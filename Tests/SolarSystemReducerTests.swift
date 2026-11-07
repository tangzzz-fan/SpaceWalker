import XCTest
@testable import SpaceWalker

final class SolarSystemReducerTests: XCTestCase {
    private func reduce(_ actions: [SolarSystemAction]) -> SolarSystemState {
        var state = SolarSystemState()
        for action in actions {
            SolarSystemReducer.reduce(&state, action)
        }
        return state
    }

    func testAdvanceUsesRate() {
        let state = reduce([.setRate(2), .advance(seconds: 3)])
        XCTAssertEqual(state.days, 6, accuracy: 0.0001)
    }

    func testPausedStopsAdvance() {
        let state = reduce([.togglePause, .advance(seconds: 10)])
        XCTAssertEqual(state.days, 0, accuracy: 0.0001)
    }

    func testRateIsClampedToRange() {
        XCTAssertEqual(reduce([.setRate(1_000)]).daysPerSecond, SolarSystemState.rateRange.upperBound)
        XCTAssertEqual(reduce([.setRate(0.001)]).daysPerSecond, SolarSystemState.rateRange.lowerBound)
    }

    func testNegativeOrZeroAdvanceIsIgnored() {
        XCTAssertEqual(reduce([.advance(seconds: 0)]).days, 0)
        XCTAssertEqual(reduce([.advance(seconds: -5)]).days, 0)
    }

    func testSelectionCanBeCleared() {
        XCTAssertEqual(reduce([.select(.earth)]).selected, .earth)
        XCTAssertNil(reduce([.select(.earth), .select(nil)]).selected)
    }

    func testOrbitsToggle() {
        XCTAssertFalse(reduce([.toggleOrbits]).showsOrbits)
        XCTAssertTrue(reduce([.toggleOrbits, .toggleOrbits]).showsOrbits)
    }

    func testResetClearsDaysAndSelection() {
        let state = reduce([.advance(seconds: 100), .select(.mars), .reset])
        XCTAssertEqual(state.days, 0, accuracy: 0.0001)
        XCTAssertNil(state.selected)
    }

    func testDaysWrapAtCeiling() {
        var state = SolarSystemState()
        state.days = SolarSystemState.dayCeiling - 1
        SolarSystemReducer.reduce(&state, .setRate(30))
        SolarSystemReducer.reduce(&state, .advance(seconds: 10))
        XCTAssertLessThan(state.days, SolarSystemState.dayCeiling)
        XCTAssertGreaterThanOrEqual(state.days, 0)
    }

    func testSelectionDoesNotResetTime() {
        let state = reduce([.advance(seconds: 50), .select(.jupiter)])
        XCTAssertEqual(state.days, 50, accuracy: 0.0001)
        XCTAssertEqual(state.selected, .jupiter)
    }
}
