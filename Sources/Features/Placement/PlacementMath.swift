import Foundation
import simd

enum PlacementMath {
    static let driftThresholdMeters: Float = 0.2
    static let cubeHeight: Float = 0.08

    static func surfaceNormal(_ normal: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(normal)
        guard length > 0 else { return SIMD3(0, 1, 0) }
        let unit = normal / length
        return unit.y < 0 ? -unit : unit
    }

    static func snappedCenter(
        hit: SIMD3<Float>,
        normal: SIMD3<Float>,
        height: Float = cubeHeight
    ) -> SIMD3<Float> {
        hit + surfaceNormal(normal) * (height / 2)
    }

    static func orientation(normal: SIMD3<Float>) -> simd_quatf {
        simd_quatf(from: SIMD3(0, 1, 0), to: surfaceNormal(normal))
    }

    static func drift(from initial: SIMD3<Float>, to current: SIMD3<Float>) -> Float {
        simd_distance(initial, current)
    }

    static func exceedsDrift(
        _ drift: Float,
        threshold: Float = driftThresholdMeters
    ) -> Bool {
        drift > threshold
    }
}

enum PlacementRules {
    static let lostSurfaceSeconds: TimeInterval = 5

    static func shouldPromptReplace(secondsSinceSurfaceHit: TimeInterval) -> Bool {
        secondsSinceSurfaceHit >= lostSurfaceSeconds
    }
}
