import XCTest

@testable import SpaceWalker

final class SessionLifecycleTests: XCTestCase {
    func testAppearStartsFromIdle() {
        let transition = SessionLifecycle.transition(from: .idle, on: .appeared)
        XCTAssertEqual(transition.phase, .running)
        XCTAssertEqual(transition.command, .start)
    }

    func testAppearWhileRunningDoesNotRestart() {
        let transition = SessionLifecycle.transition(from: .running, on: .appeared)
        XCTAssertEqual(transition.phase, .running)
        XCTAssertNil(transition.command)
    }

    func testDisappearStopsFromEveryLivePhase() {
        for phase in [SessionPhase.running, .suspended, .interrupted, .failed] {
            let transition = SessionLifecycle.transition(from: phase, on: .disappeared)
            XCTAssertEqual(transition.phase, .idle, "phase \(phase)")
            XCTAssertEqual(transition.command, .stop, "phase \(phase)")
        }
    }

    func testDisappearFromIdleIsNoOp() {
        let transition = SessionLifecycle.transition(from: .idle, on: .disappeared)
        XCTAssertEqual(transition.phase, .idle)
        XCTAssertNil(transition.command)
    }

    func testBackgroundSuspendsRunningSession() {
        let transition = SessionLifecycle.transition(from: .running, on: .enteredBackground)
        XCTAssertEqual(transition.phase, .suspended)
        XCTAssertEqual(transition.command, .suspend)
    }

    func testForegroundResumesSuspendedSession() {
        let transition = SessionLifecycle.transition(from: .suspended, on: .becameActive)
        XCTAssertEqual(transition.phase, .running)
        XCTAssertEqual(transition.command, .resume)
    }

    func testInactiveInterruptsRunningSession() {
        let transition = SessionLifecycle.transition(from: .running, on: .becameInactive)
        XCTAssertEqual(transition.phase, .interrupted)
        XCTAssertEqual(transition.command, .suspend)
    }

    func testForegroundResumesInterruptedSession() {
        let transition = SessionLifecycle.transition(from: .interrupted, on: .becameActive)
        XCTAssertEqual(transition.phase, .running)
        XCTAssertEqual(transition.command, .resume)
    }

    func testBackgroundFromInterruptedKeepsInterruptedPhase() {
        let transition = SessionLifecycle.transition(from: .interrupted, on: .enteredBackground)
        XCTAssertEqual(transition.phase, .interrupted)
        XCTAssertNil(transition.command)
    }

    func testFailedSessionDoesNotSilentlyResume() {
        let transition = SessionLifecycle.transition(from: .failed, on: .becameActive)
        XCTAssertEqual(transition.phase, .failed)
        XCTAssertNil(transition.command)
    }

    func testFailedSessionRestartsOnReappear() {
        let transition = SessionLifecycle.transition(from: .failed, on: .appeared)
        XCTAssertEqual(transition.phase, .running)
        XCTAssertEqual(transition.command, .start)
    }

    func testBackgroundCycleReturnsToRunning() {
        var phase = SessionPhase.idle
        for event in [SessionEvent.appeared, .enteredBackground, .becameActive] {
            phase = SessionLifecycle.transition(from: phase, on: event).phase
        }
        XCTAssertEqual(phase, .running)
    }
}
