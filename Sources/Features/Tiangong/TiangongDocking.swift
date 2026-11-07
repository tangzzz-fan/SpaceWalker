import Foundation
import simd

/// 交会对接判定。六自由度控制只是输入，能否锁上由这里的四个条件决定，
/// 全部纯函数，可脱离场景单测。
enum TiangongDocking {
    /// 接近速度上限（展示坐标，0.02 m/s）。
    static let maxApproachSpeed: Float = 0.02
    /// 接触时的横向偏差上限（2cm）。
    static let axialTolerance: Float = 0.02
    /// 姿态偏差上限（度）。
    static let angleTolerance: Float = 5
    /// 角速度上限（度/秒）。
    static let maxAngularSpeed: Float = 5
    /// 保持时间：进入容差后要稳住的时长。
    static let holdDuration: TimeInterval = 1.0
    /// 任务超时。
    static let timeout: TimeInterval = 90

    enum Failure: String, Equatable, Sendable {
        case tooFast
        case offAxis
        case tooSteep
        case timeout

        var message: String {
            switch self {
            case .tooFast: "接近速度过快"
            case .offAxis: "横向偏差过大，撞偏了"
            case .tooSteep: "姿态偏角过大"
            case .timeout: "超时未完成"
            }
        }
    }

    enum Outcome: Equatable, Sendable {
        case approaching
        case holding(TimeInterval)
        case docked
        case failed(Failure)
    }

    struct Input: Equatable, Sendable {
        /// 飞船相对对接口的位置：x/y 横向，z 轴向（0 = 贴住）。
        var offset: SIMD3<Float>
        /// 姿态偏差（度），取 yaw 与 pitch 中较大的分量。
        var angleDegrees: Float
        var speed: Float
        var angularSpeed: Float
        var elapsed: TimeInterval
        var holding: TimeInterval

        init(
            offset: SIMD3<Float>,
            angleDegrees: Float = 0,
            speed: Float = 0,
            angularSpeed: Float = 0,
            elapsed: TimeInterval = 0,
            holding: TimeInterval = 0
        ) {
            self.offset = offset
            self.angleDegrees = angleDegrees
            self.speed = speed
            self.angularSpeed = angularSpeed
            self.elapsed = elapsed
            self.holding = holding
        }
    }

    /// 判定顺序就是玩家能感知的顺序：先超时，再「还没靠近」，最后才是接触瞬间的四类失败。
    static func judge(_ input: Input, delta: TimeInterval) -> Outcome {
        if input.elapsed >= timeout {
            return .failed(.timeout)
        }

        let axial = abs(input.offset.z)
        guard axial <= axialTolerance else {
            return .approaching
        }

        if input.speed > maxApproachSpeed {
            return .failed(.tooFast)
        }
        if abs(input.offset.x) > axialTolerance || abs(input.offset.y) > axialTolerance {
            return .failed(.offAxis)
        }
        if input.angleDegrees > angleTolerance {
            return .failed(.tooSteep)
        }

        let holding = input.holding + delta
        return holding >= holdDuration ? .docked : .holding(holding)
    }

    enum ControlMode: String, Equatable, Sendable {
        case coarse
        case fine

        var sensitivity: Float {
            switch self {
            case .coarse: 1
            case .fine: 0.25
            }
        }
    }

    /// 六自由度输入映射：拖动走横向，捏合走轴向，模式只改灵敏度。
    /// 姿态微调（俯仰/偏航）暂不接手势，由设备姿态留给后续。
    static func offsetDelta(
        drag: CGSize,
        magnification: CGFloat,
        mode: ControlMode,
        metersPerPoint: Float
    ) -> SIMD3<Float> {
        let scale = metersPerPoint * mode.sensitivity
        let lateral = SIMD3<Float>(Float(drag.width) * scale, Float(-drag.height) * scale, 0)
        let axial = Float(magnification - 1) * scale * 8
        return lateral + SIMD3(0, 0, -axial)
    }
}
