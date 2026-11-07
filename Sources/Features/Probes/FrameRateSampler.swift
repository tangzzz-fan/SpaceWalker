import Foundation

struct FrameRateSampler: Equatable, Sendable {
    let window: Int
    let hitchThreshold: TimeInterval
    private var deltas: [TimeInterval] = []

    init(window: Int = 120, hitchThreshold: TimeInterval = 1.0 / 30.0) {
        self.window = window
        self.hitchThreshold = hitchThreshold
    }

    mutating func append(_ delta: TimeInterval) {
        guard delta > 0 else { return }
        deltas.append(delta)
        if deltas.count > window {
            deltas.removeFirst(deltas.count - window)
        }
    }

    mutating func reset() {
        deltas.removeAll()
    }

    var sampleCount: Int {
        deltas.count
    }

    var averageFPS: Double {
        guard !deltas.isEmpty else { return 0 }
        let total = deltas.reduce(0, +)
        return total > 0 ? Double(deltas.count) / total : 0
    }

    var minimumFPS: Double {
        guard let worst = deltas.max(), worst > 0 else { return 0 }
        return 1.0 / worst
    }

    var hitchCount: Int {
        deltas.count { $0 > hitchThreshold }
    }

    var hitchRatio: Double {
        deltas.isEmpty ? 0 : Double(hitchCount) / Double(deltas.count)
    }
}
