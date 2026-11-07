import XCTest

@testable import SpaceWalker

final class AppClockTests: XCTestCase {
    func testMillisecondsRoundsToNearest() {
        XCTAssertEqual(AppClock.milliseconds(from: 100, to: 100.4), 400)
        XCTAssertEqual(AppClock.milliseconds(from: 100, to: 101.25), 1250)
        XCTAssertEqual(AppClock.milliseconds(from: 100, to: 100), 0)
    }
}
