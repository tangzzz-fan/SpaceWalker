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

    func testDaysClampAtOneYear() {
        var state = SolarSystemState()
        state.days = SolarSystemState.scrubRange.upperBound - 1
        SolarSystemReducer.reduce(&state, .setRate(30))
        SolarSystemReducer.reduce(&state, .advance(seconds: 10))
        XCTAssertEqual(state.days, SolarSystemState.scrubRange.upperBound, accuracy: 0.0001)
    }

    func testScrubClampsBothEnds() {
        XCTAssertEqual(reduce([.scrub(days: 9999)]).days, SolarSystemState.scrubRange.upperBound)
        XCTAssertEqual(reduce([.scrub(days: -9999)]).days, SolarSystemState.scrubRange.lowerBound)
        XCTAssertEqual(reduce([.scrub(days: -100)]).days, -100, accuracy: 0.0001)
    }

    func testEpochIsTodayMidnightUTCPlus8() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = Date()
        let state = SolarSystemState()
        let expected = Ephemeris.julianDay(utc: calendar.startOfDay(for: now))
        XCTAssertEqual(state.epochJulianDay, expected, accuracy: 1e-9)
        XCTAssertEqual(state.julianDay, state.epochJulianDay + state.days, accuracy: 1e-9)
    }

    func testSelectionDoesNotResetTime() {
        let state = reduce([.advance(seconds: 50), .select(.jupiter)])
        XCTAssertEqual(state.days, 50, accuracy: 0.0001)
        XCTAssertEqual(state.selected, .jupiter)
    }
}
