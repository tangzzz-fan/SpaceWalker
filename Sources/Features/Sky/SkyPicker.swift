import Foundation
import Observation
import simd

enum SkyPicker {
    static let crosshairRadius: CGFloat = 22
    static let prefilterDegrees: Float = 4
    static let candidateLimit = 4

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
