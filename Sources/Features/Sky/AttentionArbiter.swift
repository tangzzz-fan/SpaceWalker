import Foundation

struct AttentionArbiter: Equatable, Sendable {
    static let required: TimeInterval = 0.6

    enum Target: Equatable, Sendable {
        case star(Star)
        case constellation(String)
        case pattern(String)
    }

    struct Candidates: Equatable, Sendable {
        var star: Star?
        var constellation: String?
        var pattern: String?
    }

    enum Effect: Equatable, Sendable {
        case highlight(Target?)
        case confirmed(Target)
    }

    struct Step: Equatable, Sendable {
        var progress: Double
        var effects: [Effect]
    }

    private(set) var progress: Double = 0
    private(set) var focus: Target?
    private(set) var confirmed: Target?

    private var dwell = DwellSelector()
    private var tracks: [RegionKind: Track] = [:]
    private var dismissed: [RegionKind: String] = [:]
    private var lastTimestamp: TimeInterval?

    mutating func step(now: TimeInterval, candidates: Candidates) -> Step {
        let delta = lastTimestamp.map { min(max(now - $0, 0), DwellSelector.maximumStep) } ?? 0
        lastTimestamp = now
        var effects: [Effect] = []

        let hit = dwell.update(candidate: candidates.star, at: now)

        // 优先级：星体 > 星座轮廓 > 星群。指着猎户座就说猎户座，
        // 只有落在没有轮廓的天区里，星群才有资格说话。
        if candidates.star != nil {
            clear(.constellation, effects: &effects)
            clear(.pattern, effects: &effects)
            progress = dwell.progress
            if let hit {
                confirmed = .star(hit)
                effects.append(.confirmed(.star(hit)))
            }
            return Step(progress: progress, effects: effects)
        }

        if let key = candidates.constellation {
            clear(.pattern, effects: &effects)
            advance(.constellation, key: key, delta: delta, effects: &effects)
            progress = tracks[.constellation]?.progress ?? 0
        } else if let key = candidates.pattern {
            clear(.constellation, effects: &effects)
            advance(.pattern, key: key, delta: delta, effects: &effects)
            progress = tracks[.pattern]?.progress ?? 0
        } else {
            clear(.constellation, effects: &effects)
            clear(.pattern, effects: &effects)
            progress = dwell.progress
        }

        return Step(progress: progress, effects: effects)
    }

    mutating func dismiss(_ target: Target) {
        switch target {
        case .star(let star):
            if confirmed == .star(star) { confirmed = nil }
        case .constellation(let key):
            dismissed[.constellation] = key
            tracks[.constellation]?.confirmed = false
            if confirmed == target { confirmed = nil }
        case .pattern(let key):
            dismissed[.pattern] = key
            tracks[.pattern]?.confirmed = false
            if confirmed == target { confirmed = nil }
        }
    }

    mutating func reset() {
        dwell.reset()
        tracks = [:]
        dismissed = [:]
        lastTimestamp = nil
        progress = 0
        focus = nil
        confirmed = nil
    }

    mutating func resetStar() {
        dwell.reset()
        progress = 0
        if case .star = confirmed { confirmed = nil }
    }

    private mutating func advance(
        _ kind: RegionKind,
        key: String,
        delta: TimeInterval,
        effects: inout [Effect]
    ) {
        let target = kind.target(key)
        var track = tracks[kind] ?? Track()

        if track.target != target {
            track = Track(target: target)
            if focus != target {
                focus = target
                effects.append(.highlight(target))
            }
        } else {
            track.elapsed = min(track.elapsed + delta, Self.required)
        }

        if track.elapsed >= Self.required - 1e-9,
           !track.confirmed,
           dismissed[kind] != key {
            track.confirmed = true
            confirmed = target
            effects.append(.confirmed(target))
        }

        tracks[kind] = track
    }

    private mutating func clear(_ kind: RegionKind, effects: inout [Effect]) {
        guard let target = tracks[kind]?.target else { return }
        tracks[kind] = nil
        if focus == target {
            focus = nil
            effects.append(.highlight(nil))
        }
        if confirmed == target { confirmed = nil }
        dismissed[kind] = nil
    }

    private enum RegionKind: Hashable {
        case constellation
        case pattern

        func target(_ key: String) -> Target {
            switch self {
            case .constellation: return .constellation(key)
            case .pattern: return .pattern(key)
            }
        }
    }

    private struct Track: Equatable, Sendable {
        var target: Target?
        var elapsed: TimeInterval = 0
        var confirmed = false

        var progress: Double {
            min(max(elapsed / AttentionArbiter.required, 0), 1)
        }
    }
}
