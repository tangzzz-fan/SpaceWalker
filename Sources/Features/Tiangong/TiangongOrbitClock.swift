import Foundation
import simd

/// 一个轨道周期的时钟。只做两件事：推动太阳方向、推动圈数。
/// 一圈 90 分钟是模型时间，展示倍率是「多少真实秒走完一圈」——
/// 两者必须分开，否则改倍率会连带改物理量。
struct TiangongOrbitClock: Equatable {
    static let orbitDuration: Double = 90 * 60
    static let paceSlow: Double = 60
    static let paceFast: Double = 10

    private(set) var phase: Double
    private(set) var completedOrbits: Int = 0
    private(set) var modelSeconds: Double = 0

    init(phase: Double = 0.18) {
        self.phase = phase
    }

    var sunAngle: Float {
        Float(phase * 2 * .pi)
    }

    var sunDirection: SIMD3<Float> {
        SIMD3(0, sin(sunAngle), cos(sunAngle))
    }

    /// 太阳翼绕自身长轴转过的角度：让翼面法线指向太阳。
    var wingAngle: Float {
        .pi / 2 - sunAngle
    }

    mutating func step(realSeconds: Double, pace: Double, paused: Bool) {
        guard !paused, pace > 0, realSeconds > 0 else { return }
        phase += realSeconds / pace
        while phase >= 1 {
            phase -= 1
            completedOrbits += 1
        }
        modelSeconds += realSeconds * (Self.orbitDuration / pace)
    }
}
