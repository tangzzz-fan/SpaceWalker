import Foundation
import simd

enum PrototypeLogic {
    static let minScale: Float = 0.6
    static let maxScale: Float = 2.5
    static let maxRadius: Float = 0.6
    static let metersPerPoint: Float = 0.0015

    static func clampScale(_ value: Float) -> Float {
        min(max(value, minScale), maxScale)
    }

    static func clampPosition(_ position: SIMD3<Float>) -> SIMD3<Float> {
        var result = position
        result.y = 0

        let planar = SIMD2(result.x, result.z)
        let distance = simd_length(planar)
        guard distance > maxRadius else { return result }

        let factor = maxRadius / distance
        result.x = planar.x * factor
        result.z = planar.y * factor
        return result
    }

    static func dragOffset(translation: CGSize) -> SIMD3<Float> {
        SIMD3(
            Float(translation.width) * metersPerPoint,
            0,
            Float(translation.height) * metersPerPoint
        )
    }
}
