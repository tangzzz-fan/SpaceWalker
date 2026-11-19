import Foundation

struct FrameRateSampler: Equatable, Sendable {
    let window: Int
    let hitchThreshold: TimeInterval
    /// 启动尖峰豁免：只在窗口尚未填满（启动阶段）时生效。首帧前的环境加载/建模
    /// 会产生一次性长帧（实测 ~0.36s），它不是运行期卡顿；窗口填满后不再豁免，
    /// 运行期真卡顿必须照记。
    let startupSpikeThreshold: TimeInterval
    private var deltas: [TimeInterval] = []

    init(
        window: Int = 120,
        hitchThreshold: TimeInterval = 1.0 / 30.0,
        startupSpikeThreshold: TimeInterval = 0.25
    ) {
        self.window = window
        self.hitchThreshold = hitchThreshold
        self.startupSpikeThreshold = startupSpikeThreshold
    }

    mutating func append(_ delta: TimeInterval) {
        guard delta > 0 else { return }
        if deltas.count < window && delta > startupSpikeThreshold { return }
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
