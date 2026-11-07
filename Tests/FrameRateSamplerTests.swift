import XCTest

@testable import SpaceWalker

final class FrameRateSamplerTests: XCTestCase {
    func testAverageFPSFromStableSixtyFrames() {
        var sampler = FrameRateSampler()
        for _ in 0..<60 {
            sampler.append(1.0 / 60.0)
        }
        XCTAssertEqual(sampler.averageFPS, 60, accuracy: 0.01)
        XCTAssertEqual(sampler.minimumFPS, 60, accuracy: 0.01)
        XCTAssertEqual(sampler.hitchCount, 0)
    }

    func testMinimumFPSReflectsWorstFrame() {
        var sampler = FrameRateSampler()
        sampler.append(1.0 / 60.0)
        sampler.append(1.0 / 30.0)
        sampler.append(1.0 / 60.0)
        XCTAssertEqual(sampler.minimumFPS, 30, accuracy: 0.01)
    }

    func testHitchesCountFramesBelowThirtyFPS() {
        var sampler = FrameRateSampler(hitchThreshold: 1.0 / 30.0)
        sampler.append(1.0 / 60.0)
        sampler.append(0.05)
        sampler.append(0.1)
        XCTAssertEqual(sampler.hitchCount, 2)
        XCTAssertEqual(sampler.hitchRatio, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testWindowKeepsOnlyRecentFrames() {
        var sampler = FrameRateSampler(window: 3)
        for delta in [0.1, 0.1, 0.016, 0.016, 0.016] {
            sampler.append(delta)
        }
        XCTAssertEqual(sampler.sampleCount, 3)
        XCTAssertEqual(sampler.averageFPS, 62.5, accuracy: 0.01)
    }

    func testInvalidDeltasAreIgnored() {
        var sampler = FrameRateSampler()
        sampler.append(0)
        sampler.append(-1)
        XCTAssertEqual(sampler.sampleCount, 0)
        XCTAssertEqual(sampler.averageFPS, 0)
        XCTAssertEqual(sampler.minimumFPS, 0)
    }

    func testResetClearsWindow() {
        var sampler = FrameRateSampler()
        sampler.append(0.016)
        sampler.reset()
        XCTAssertEqual(sampler.sampleCount, 0)
        XCTAssertEqual(sampler.hitchCount, 0)
    }
}
