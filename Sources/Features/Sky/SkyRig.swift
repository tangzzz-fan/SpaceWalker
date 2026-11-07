import Foundation
import simd

struct SkyRig: Equatable, Sendable {
    static let pitchRange: ClosedRange<Float> = (-1.35)...1.35
    static let dragSensitivity: Float = 0.004

    var yaw: Float = 0
    var pitch: Float = 0

    var orientation: simd_quatf {
        let yawRotation = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
        let pitchRotation = simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0))
        return yawRotation * pitchRotation
    }

    mutating func drag(deltaX: Float, deltaY: Float) {
        yaw -= deltaX * Self.dragSensitivity
        pitch = min(max(pitch + deltaY * Self.dragSensitivity, Self.pitchRange.lowerBound), Self.pitchRange.upperBound)
    }

    mutating func aim(at forward: SIMD3<Float>) {
        let normalized = simd_length(forward) > 0.0001 ? simd_normalize(forward) : SIMD3<Float>(0, 0, -1)
        yaw = atan2(normalized.x, -normalized.z)
        pitch = min(max(asin(min(max(normalized.y, -1), 1)), Self.pitchRange.lowerBound), Self.pitchRange.upperBound)
    }
}

enum AttitudeMath {
    static func forward(from matrix: simd_float3x3) -> SIMD3<Float> {
        matrix * SIMD3<Float>(0, 0, -1)
    }
}
