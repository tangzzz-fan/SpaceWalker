import Foundation
import Observation
import simd

enum SkyPicker {
    static let crosshairRadius: CGFloat = 22
    static let prefilterDegrees: Float = 4
    static let candidateLimit = 4

    static func nearby(
        to star: Star,
        in stars: [Star],
        within degrees: Double = 1.5,
        limit: Int = 4
    ) -> [Star] {
        let origin = direction(for: star)
        let threshold = Float(cos(degrees * .pi / 180))
        return stars
            .filter { $0.isSelectable && $0.name != star.name }
            .filter { simd_dot(origin, direction(for: $0)) > threshold }
            .sorted { $0.magnitude < $1.magnitude }
            .prefix(limit)
            .map { $0 }
    }

    /// 一组方向的中心：取「能盖住所有方向的最小圆的圆心」。
    ///
    /// 用平均方向（质心）会偏：人马座骨架质心离包围中心 2.4°，
    /// 定位过去茶壶就贴着屏幕边缘。最小覆盖圆的圆心是两两中点里的最优解，
    /// 二十几颗星穷举也就几百次。
    static func enclosingCenter(of directions: [SIMD3<Float>]) -> SIMD3<Float>? {
        let unit = directions.map(simd_normalize).filter { simd_length($0) > 0.5 }
        guard unit.count > 1 else { return unit.first }
        var best: (center: SIMD3<Float>, radius: Float)?
        for first in 0..<unit.count {
            for second in (first + 1)..<unit.count {
                let sum = unit[first] + unit[second]
                guard simd_length(sum) > 0.001 else { continue }
                let center = simd_normalize(sum)
                var radius: Float = 0
                for vector in unit {
                    radius = max(radius, acos(min(Float(1), simd_dot(center, vector))))
                }
                if best == nil || radius < best!.radius {
                    best = (center, radius)
                }
            }
        }
        return best?.center
    }

    static func offsetDegrees(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Double {
        let normalizedA = simd_length(a) > 0.0001 ? simd_normalize(a) : SIMD3<Float>(0, 0, -1)
        let normalizedB = simd_length(b) > 0.0001 ? simd_normalize(b) : SIMD3<Float>(0, 0, -1)
        let dot = simd_dot(normalizedA, normalizedB)
        return acos(Double(min(max(dot, -1), 1))) * 180 / .pi
    }

    static func direction(for star: Star) -> SIMD3<Float> {
        StarField.direction(
            rightAscensionHours: star.rightAscensionHours,
            declinationDegrees: star.declinationDegrees
        )
    }

    static func nearest(to viewDirection: SIMD3<Float>, in stars: [Star], limit: Int = candidateLimit) -> [Star] {
        guard simd_length(viewDirection) > 0.0001 else { return [] }
        let unit = simd_normalize(viewDirection)
        let threshold = cos(prefilterDegrees * .pi / 180)

        var scored: [(star: Star, alignment: Float)] = []
        scored.reserveCapacity(32)
        for star in stars where star.isSelectable {
            let alignment = simd_dot(unit, direction(for: star))
            guard alignment > threshold else { continue }
            scored.append((star, alignment))
        }

        scored.sort { lhs, rhs in
            if abs(lhs.alignment - rhs.alignment) > 1e-6 {
                return lhs.alignment > rhs.alignment
            }
            return lhs.star.magnitude < rhs.star.magnitude
        }
        return scored.prefix(limit).map(\.star)
    }

    static func angularDistance(_ lhs: Star, _ rhs: Star) -> Double {
        let alignment = simd_dot(direction(for: lhs), direction(for: rhs))
        return acos(Double(min(max(alignment, -1), 1))) * 180 / .pi
    }
}

struct DwellSelector: Equatable, Sendable {
    static let required: TimeInterval = 0.6
    static let decayRate: Double = 1.5
    static let maximumStep: TimeInterval = 0.1
    static let rearmDelay: TimeInterval = 0.3

    private(set) var target: Star?
    private(set) var elapsed: TimeInterval = 0
    private var lastTimestamp: TimeInterval?
    private var absentSince: TimeInterval?
    private var isArmed = true

    var progress: Double {
        min(max(elapsed / Self.required, 0), 1)
    }

    mutating func update(candidate: Star?, at timestamp: TimeInterval) -> Star? {
        let step = lastTimestamp.map { min(max(timestamp - $0, 0), Self.maximumStep) } ?? 0
        lastTimestamp = timestamp

        guard isArmed else {
            if let candidate, candidate != target {
                isArmed = true
                target = candidate
                elapsed = 0
                absentSince = nil
                return nil
            }
            guard candidate == nil else {
                absentSince = nil
                return nil
            }
            let since = absentSince ?? timestamp
            absentSince = since
            if timestamp - since >= Self.rearmDelay {
                isArmed = true
                target = nil
                elapsed = 0
                absentSince = nil
            }
            return nil
        }

        guard let candidate else {
            target = nil
            elapsed = max(elapsed - step * Self.decayRate, 0)
            return nil
        }

        guard candidate == target else {
            target = candidate
            elapsed = 0
            return nil
        }

        elapsed = min(elapsed + step, Self.required)
        guard elapsed >= Self.required - 1e-9 else { return nil }
        isArmed = false
        return candidate
    }

    mutating func reset() {
        target = nil
        elapsed = 0
        absentSince = nil
        lastTimestamp = nil
        isArmed = true
    }
}

@MainActor
@Observable
final class DwellHUD {
    var progress: Double = 0

    func show(_ value: Double) {
        guard abs(value - progress) > 0.005 else { return }
        progress = value
    }
}
