import Foundation
import simd

struct DriftSummary: Equatable, Sendable {
    var maxDisplacement: Float
    var direction: SIMD3<Float>
    var sampleCount: Int
    var jumpCount: Int
}

enum DriftTrack {
    static let jumpThreshold: Float = 0.5

    static func summarize(
        _ samples: [SIMD3<Float>],
        jumpThreshold: Float = jumpThreshold
    ) -> DriftSummary? {
        guard let first = samples.first, samples.count > 1 else { return nil }

        var origin = first
        var previous = first
        var maxDisplacement: Float = 0
        var direction = SIMD3<Float>(0, 0, 0)
        var jumps = 0

        for sample in samples.dropFirst() {
            if simd_distance(sample, previous) > jumpThreshold {
                jumps += 1
                origin = sample
                previous = sample
                continue
            }
            previous = sample

            let offset = sample - origin
            let distance = simd_length(offset)
            if distance > maxDisplacement {
                maxDisplacement = distance
                direction = distance > 0 ? offset / distance : .zero
            }
        }

        return DriftSummary(
            maxDisplacement: maxDisplacement,
            direction: direction,
            sampleCount: samples.count,
            jumpCount: jumps
        )
    }

    static func shouldSample(
        lastSampleTime: TimeInterval?,
        now: TimeInterval,
        interval: TimeInterval = 1
    ) -> Bool {
        guard let lastSampleTime else { return true }
        return now - lastSampleTime >= interval
    }
}
