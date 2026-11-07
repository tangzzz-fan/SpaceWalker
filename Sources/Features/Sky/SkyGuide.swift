import Foundation
import simd

struct GuideVector: Equatable, Sendable {
    var yaw: Double
    var pitch: Double
    var distance: Double

    var isAligned: Bool {
        distance <= SkyGuide.arrivalDegrees
    }

    var instruction: String {
        guard !isAligned else { return "已对准" }
        let horizontal = abs(yaw) < 1 ? "保持" : (yaw > 0 ? String(format: "右转 %.0f°", yaw) : String(format: "左转 %.0f°", -yaw))
        let vertical = abs(pitch) < 1 ? "保持" : (pitch > 0 ? String(format: "抬高 %.0f°", pitch) : String(format: "压低 %.0f°", -pitch))
        return "\(horizontal) · \(vertical)"
    }

    var arrowDegrees: Double {
        atan2(yaw, pitch) * 180 / .pi
    }
}

enum SkyGuide {
    static let arrivalDegrees: Double = 3

    static func vector(to direction: SIMD3<Float>) -> GuideVector {
        let length = simd_length(direction)
        guard length > 0.0001 else {
            return GuideVector(yaw: 0, pitch: 0, distance: 180)
        }
        let unit = direction / length
        let yaw = Double(atan2(unit.x, -unit.z)) * 180 / .pi
        let pitch = Double(asin(min(max(unit.y, -1), 1))) * 180 / .pi
        let alignment = simd_dot(unit, SIMD3<Float>(0, 0, -1))
        let distance = acos(Double(min(max(alignment, -1), 1))) * 180 / .pi
        return GuideVector(yaw: yaw, pitch: pitch, distance: distance)
    }
}
