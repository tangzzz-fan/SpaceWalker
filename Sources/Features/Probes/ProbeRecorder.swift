import Foundation
import os
import RealityKit
import SwiftUI

/// 帧间隔的线程安全盒子：`SceneEvents.Update` 在渲染线程回调，读数在主线程拿，
/// 两边不能直接共享一个 struct。星图探针也用它。
final class FrameRateBox: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: FrameRateSampler())

    func append(_ delta: TimeInterval) {
        lock.withLock { $0.append(delta) }
    }

    func snapshot() -> FrameRateSampler {
        lock.withLock { $0 }
    }
}

@MainActor
final class ProbeRecorder {
    private let frames = FrameRateBox()
    private var subscription: EventSubscription?
    private var driftPositions: [SIMD3<Float>] = []
    private var lastDriftSample: TimeInterval?
    private var lastFPSLog: TimeInterval?

    private(set) var summary = ProbeSummary()

    func attach(_ content: RealityViewCameraContent) {
        let frames = frames
        subscription = content.subscribe(to: SceneEvents.Update.self) { event in
            frames.append(event.deltaTime)
        }
    }

    func tick(now: TimeInterval, anchorPosition: SIMD3<Float>?) -> ProbeSummary {
        let sampler = frames.snapshot()
        summary.fps = sampler.averageFPS
        summary.minimumFPS = sampler.minimumFPS
        summary.hitches = sampler.hitchCount

        if DriftTrack.shouldSample(lastSampleTime: lastDriftSample, now: now),
           let anchorPosition {
            lastDriftSample = now
            driftPositions.append(anchorPosition)
            if let drift = DriftTrack.summarize(driftPositions) {
                summary.maxDriftMeters = drift.maxDisplacement
                summary.driftDirection = drift.direction
                summary.driftSamples = drift.sampleCount
                summary.driftJumps = drift.jumpCount
                SessionLog.append(
                    String(
                        format: "probe.drift samples=%d max=%.3f jumps=%d dir=(%.2f,%.2f,%.2f)",
                        drift.sampleCount,
                        drift.maxDisplacement,
                        drift.jumpCount,
                        drift.direction.x,
                        drift.direction.y,
                        drift.direction.z
                    )
                )
            }
        }

        if DriftTrack.shouldSample(lastSampleTime: lastFPSLog, now: now, interval: 5) {
            lastFPSLog = now
            SessionLog.append(
                String(
                    format: "probe.fps avg=%.1f min=%.1f hitches=%d",
                    summary.fps,
                    summary.minimumFPS,
                    summary.hitches
                )
            )
        }

        return summary
    }

}

struct ProbeSummary: Equatable, Sendable {
    var fps: Double = 0
    var minimumFPS: Double = 0
    var hitches: Int = 0
    var maxDriftMeters: Float = 0
    var driftDirection: SIMD3<Float> = .zero
    var driftSamples: Int = 0
    var driftJumps: Int = 0

    var fpsOnlyLine: String {
        String(format: "%.0ffps · min %.0f · 卡顿 %d", fps, minimumFPS, hitches)
    }

    var line: String {
        String(
            format: "%.0ffps · min %.0f · 卡顿 %d · 漂移 %.1fcm",
            fps,
            minimumFPS,
            hitches,
            maxDriftMeters * 100
        )
    }
}
