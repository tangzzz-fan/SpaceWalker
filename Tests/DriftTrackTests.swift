import XCTest
import simd

@testable import SpaceWalker

final class DriftTrackTests: XCTestCase {
    func testSingleSampleHasNoSummary() {
        XCTAssertNil(DriftTrack.summarize([SIMD3(0, 0, 0)]))
        XCTAssertNil(DriftTrack.summarize([]))
    }

    func testMaxDisplacementAndDirection() {
        let samples: [SIMD3<Float>] = [
            SIMD3(0, 0, 0),
            SIMD3(0.05, 0, 0),
            SIMD3(0.2, 0, 0),
            SIMD3(0.1, 0, 0),
        ]
        let summary = DriftTrack.summarize(samples)
        XCTAssertEqual(summary?.maxDisplacement ?? 0, 0.2, accuracy: 0.0001)
        XCTAssertEqual(summary?.direction.x ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(summary?.sampleCount, 4)
        XCTAssertEqual(summary?.jumpCount, 0)
    }

    func testDirectionIsNormalised() {
        let samples: [SIMD3<Float>] = [SIMD3(0, 0, 0), SIMD3(0.03, 0.04, 0)]
        let summary = DriftTrack.summarize(samples)
        let length = simd_length(summary?.direction ?? .zero)
        XCTAssertEqual(length, 1, accuracy: 0.0001)
        XCTAssertEqual(summary?.maxDisplacement ?? 0, 0.05, accuracy: 0.0001)
    }

    func testDriftIsMeasuredFromFirstSample() {
        let samples: [SIMD3<Float>] = [SIMD3(1, 1, 1), SIMD3(1.1, 1, 1)]
        let summary = DriftTrack.summarize(samples)
        XCTAssertEqual(summary?.maxDisplacement ?? 0, 0.1, accuracy: 0.0001)
    }

    func testSamplingGateRespectsInterval() {
        XCTAssertTrue(DriftTrack.shouldSample(lastSampleTime: nil, now: 10))
        XCTAssertFalse(DriftTrack.shouldSample(lastSampleTime: 10, now: 10.5))
        XCTAssertTrue(DriftTrack.shouldSample(lastSampleTime: 10, now: 11))
        XCTAssertTrue(DriftTrack.shouldSample(lastSampleTime: 10, now: 15.5, interval: 5))
    }
}

    func testAnchorJumpResetsSegment() {
        let samples: [SIMD3<Float>] = [
            SIMD3(0, 0, 0),
            SIMD3(0.02, 0, 0),
            SIMD3(1.2, 0, 0),
            SIMD3(1.23, 0, 0),
        ]
        let summary = DriftTrack.summarize(samples)
        XCTAssertEqual(summary?.jumpCount, 1)
        XCTAssertEqual(summary?.maxDisplacement ?? 0, 0.03, accuracy: 0.0001)
    }

    func testJumpThresholdIsConfigurable() {
        let samples: [SIMD3<Float>] = [SIMD3(0, 0, 0), SIMD3(0.3, 0, 0)]
        XCTAssertEqual(DriftTrack.summarize(samples)?.jumpCount, 0)
        XCTAssertEqual(
            DriftTrack.summarize(samples, jumpThreshold: 0.2)?.jumpCount,
            1
        )
    }
