import XCTest

@testable import SpaceWalker

final class AttentionArbiterTests: XCTestCase {
    private let sirius = Star(
        rightAscensionHours: 6.753,
        declinationDegrees: -16.72,
        magnitude: -1.44,
        colorIndex: 0,
        name: "Sirius",
        constellation: "CMa"
    )
    private let vega = Star(
        rightAscensionHours: 18.616,
        declinationDegrees: 38.78,
        magnitude: 0.03,
        colorIndex: 0,
        name: "Vega",
        constellation: "Lyr"
    )

    private func candidates(
        star: Star? = nil,
        constellation: String? = nil,
        pattern: String? = nil
    ) -> AttentionArbiter.Candidates {
        AttentionArbiter.Candidates(star: star, constellation: constellation, pattern: pattern)
    }

    @discardableResult
    private func run(
        _ arbiter: inout AttentionArbiter,
        from start: TimeInterval,
        count: Int,
        candidates: AttentionArbiter.Candidates
    ) -> AttentionArbiter.Step {
        var step = AttentionArbiter.Step(progress: 0, effects: [])
        for index in 0..<count {
            step = arbiter.step(now: start + Double(index) * 0.1, candidates: candidates)
        }
        return step
    }

    private func confirms(_ step: AttentionArbiter.Step) -> [AttentionArbiter.Target] {
        step.effects.compactMap { effect in
            if case .confirmed(let target) = effect { return target }
            return nil
        }
    }

    func testStarConfirmsOnceAfterThreshold() {
        var arbiter = AttentionArbiter()
        var confirmed: [AttentionArbiter.Target] = []

        for index in 0..<6 {
            confirmed += confirms(arbiter.step(now: Double(index) * 0.1, candidates: candidates(star: sirius)))
        }
        XCTAssertTrue(confirmed.isEmpty)
        XCTAssertEqual(arbiter.progress, 5.0 / 6.0, accuracy: 0.001)

        let final = arbiter.step(now: 0.6, candidates: candidates(star: sirius))
        XCTAssertEqual(final.effects, [.confirmed(.star(sirius))])
        XCTAssertEqual(arbiter.confirmed, .star(sirius))

        let again = arbiter.step(now: 0.7, candidates: candidates(star: sirius))
        XCTAssertTrue(again.effects.isEmpty)
    }

    func testStarProgressDecaysWhenLookingAway() {
        var arbiter = AttentionArbiter()
        run(&arbiter, from: 0, count: 4, candidates: candidates(star: sirius))
        XCTAssertEqual(arbiter.progress, 0.5, accuracy: 0.001)

        let result = arbiter.step(now: 0.4, candidates: candidates())
        XCTAssertEqual(result.progress, 0.15 / 0.6, accuracy: 0.001)
    }

    func testSingleStepIsCappedForStars() {
        var arbiter = AttentionArbiter()
        _ = arbiter.step(now: 0, candidates: candidates(star: sirius))
        let result = arbiter.step(now: 0.5, candidates: candidates(star: sirius))
        XCTAssertEqual(result.progress, 0.1 / 0.6, accuracy: 0.001)
    }

    func testStarOutranksConstellation() {
        var arbiter = AttentionArbiter()
        var confirmed: [AttentionArbiter.Target] = []

        for index in 0..<8 {
            confirmed += confirms(arbiter.step(
                now: Double(index) * 0.1,
                candidates: candidates(star: sirius, constellation: "Ori")
            ))
        }
        XCTAssertEqual(confirmed, [.star(sirius)])
        XCTAssertNil(arbiter.focus)
    }

    func testConstellationConfirmsAfterThreshold() {
        var arbiter = AttentionArbiter()
        var confirmed: [AttentionArbiter.Target] = []

        for index in 0..<7 {
            confirmed += confirms(arbiter.step(
                now: Double(index) * 0.1,
                candidates: candidates(constellation: "Ori")
            ))
        }
        XCTAssertEqual(confirmed, [.constellation("Ori")])
        XCTAssertEqual(arbiter.confirmed, .constellation("Ori"))
    }

    func testEnteringRegionHighlightsAndLeavingClearsIt() {
        var arbiter = AttentionArbiter()
        let enter = arbiter.step(now: 0, candidates: candidates(constellation: "Ori"))
        XCTAssertEqual(enter.effects, [.highlight(.constellation("Ori"))])

        let leave = arbiter.step(now: 0.1, candidates: candidates())
        XCTAssertEqual(leave.effects, [.highlight(nil)])
        XCTAssertNil(arbiter.confirmed)
    }

    func testDismissedConstellationStaysQuietUntilLeaving() {
        var arbiter = AttentionArbiter()
        run(&arbiter, from: 0, count: 7, candidates: candidates(constellation: "Ori"))
        XCTAssertEqual(arbiter.confirmed, .constellation("Ori"))

        arbiter.dismiss(.constellation("Ori"))
        let quiet = arbiter.step(now: 0.7, candidates: candidates(constellation: "Ori"))
        XCTAssertTrue(quiet.effects.isEmpty)
        XCTAssertNil(arbiter.confirmed)
    }

    func testLeavingRegionRearmsTheDismissal() {
        var arbiter = AttentionArbiter()
        run(&arbiter, from: 0, count: 7, candidates: candidates(constellation: "Ori"))
        arbiter.dismiss(.constellation("Ori"))
        _ = arbiter.step(now: 0.7, candidates: candidates())
        _ = arbiter.step(now: 0.8, candidates: candidates(constellation: "Ori"))

        let again = run(&arbiter, from: 0.9, count: 6, candidates: candidates(constellation: "Ori"))
        XCTAssertEqual(confirms(again), [.constellation("Ori")])
    }

    func testSwitchingRegionRestartsTimer() {
        var arbiter = AttentionArbiter()
        run(&arbiter, from: 0, count: 5, candidates: candidates(constellation: "Ori"))
        XCTAssertEqual(arbiter.progress, 0.4 / 0.6, accuracy: 0.01)

        let switched = arbiter.step(now: 0.4, candidates: candidates(constellation: "Lyr"))
        XCTAssertEqual(switched.progress, 0, accuracy: 0.001)
        XCTAssertEqual(switched.effects, [.highlight(.constellation("Lyr"))])
    }

    func testPatternYieldsToStarAndLosesItsDismissal() {
        var arbiter = AttentionArbiter()
        run(&arbiter, from: 0, count: 7, candidates: candidates(pattern: "summer"))
        XCTAssertEqual(arbiter.confirmed, .pattern("summer"))

        arbiter.dismiss(.pattern("summer"))
        let starStep = arbiter.step(now: 0.7, candidates: candidates(star: vega, pattern: "summer"))
        XCTAssertEqual(starStep.effects.first, .highlight(nil))
        XCTAssertNil(arbiter.confirmed)
    }

    func testSingleStepIsCappedForRegions() {
        var arbiter = AttentionArbiter()
        _ = arbiter.step(now: 0, candidates: candidates(constellation: "Ori"))
        let result = arbiter.step(now: 0.5, candidates: candidates(constellation: "Ori"))
        XCTAssertEqual(result.progress, 0.1 / 0.6, accuracy: 0.001)
    }

    func testConstellationOutranksPattern() {
        var arbiter = AttentionArbiter()
        let result = arbiter.step(now: 0, candidates: candidates(constellation: "Ori", pattern: "winter"))
        XCTAssertEqual(result.effects, [.highlight(.constellation("Ori"))])
    }

    func testDismissalSurvivesSwitchingRegions() {
        var arbiter = AttentionArbiter()
        run(&arbiter, from: 0, count: 7, candidates: candidates(constellation: "Ori"))
        arbiter.dismiss(.constellation("Ori"))

        _ = arbiter.step(now: 0.7, candidates: candidates(constellation: "Lyr"))
        _ = arbiter.step(now: 0.8, candidates: candidates(constellation: "Ori"))
        let back = run(&arbiter, from: 0.9, count: 8, candidates: candidates(constellation: "Ori"))
        XCTAssertTrue(confirms(back).isEmpty)
    }

    func testStarRearmsAfterLookingAway() {
        var arbiter = AttentionArbiter()
        run(&arbiter, from: 0, count: 7, candidates: candidates(star: sirius))
        run(&arbiter, from: 0.7, count: 4, candidates: candidates())

        let again = run(&arbiter, from: 1.1, count: 7, candidates: candidates(star: sirius))
        XCTAssertEqual(confirms(again), [.star(sirius)])
    }

    func testSingleStepIsCappedForPatterns() {
        var arbiter = AttentionArbiter()
        _ = arbiter.step(now: 0, candidates: candidates(pattern: "summer"))
        let result = arbiter.step(now: 0.5, candidates: candidates(pattern: "summer"))
        XCTAssertEqual(result.progress, 0.1 / 0.6, accuracy: 0.001)
    }

    func testResetStarLeavesRegionAlone() {
        var arbiter = AttentionArbiter()
        run(&arbiter, from: 0, count: 7, candidates: candidates(constellation: "Ori"))

        arbiter.resetStar()
        XCTAssertEqual(arbiter.confirmed, .constellation("Ori"))
        XCTAssertEqual(arbiter.focus, .constellation("Ori"))
    }

    func testResetClearsEverything() {
        var arbiter = AttentionArbiter()
        run(&arbiter, from: 0, count: 7, candidates: candidates(constellation: "Ori"))
        arbiter.reset()

        XCTAssertNil(arbiter.confirmed)
        XCTAssertNil(arbiter.focus)
        XCTAssertEqual(arbiter.progress, 0, accuracy: 0.0001)

        let result = arbiter.step(now: 5, candidates: candidates(constellation: "Ori"))
        XCTAssertEqual(result.progress, 0, accuracy: 0.0001)
        XCTAssertEqual(result.effects, [.highlight(.constellation("Ori"))])
    }
}
