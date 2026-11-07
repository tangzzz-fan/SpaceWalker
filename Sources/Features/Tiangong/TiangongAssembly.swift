import Foundation
import simd

/// 装配判定：三条件同时成立才吸附，全部是纯函数，可脱离 RealityKit 单测。
enum TiangongAssembly {
    /// 距离容差（展示坐标，2cm）。
    static let distanceTolerance: Float = 0.02
    /// 轴夹角容差（度）。
    static let angleTolerance: Float = 5

    enum Failure: Equatable, Sendable {
        case wrongPort
        case tooFar
        case badAngle

        var message: String {
            switch self {
            case .wrongPort: "接口不对"
            case .tooFar: "离接口太远"
            case .badAngle: "角度偏太多"
            }
        }
    }

    enum Verdict: Equatable, Sendable {
        case snap(SIMD3<Float>)
        /// push 是排斥方向（单位向量），供场景把模块推开。
        case reject(Failure, push: SIMD3<Float>)
    }

    /// - Parameters:
    ///   - port: 模块当前被送往的接口，归哪个模块所有。
    ///   - angleDegrees: 模块装配轴与接口轴的夹角。
    static func verdict(
        module: TiangongModuleID,
        at position: SIMD3<Float>,
        angleDegrees: Float = 0,
        port: TiangongModuleID
    ) -> Verdict {
        guard port == module else {
            return .reject(.wrongPort, push: SIMD3(0, 0.5, 0.5))
        }

        let target = TiangongLayout.restPosition(module)
        let delta = target - position
        let distance = simd_length(delta)
        guard distance <= distanceTolerance else {
            let push = distance > 1e-5 ? delta / distance : SIMD3(0, 1, 0)
            return .reject(.tooFar, push: push)
        }

        guard abs(angleDegrees) <= angleTolerance else {
            return .reject(.badAngle, push: SIMD3(0, 1, 0))
        }

        return .snap(target)
    }

    /// 屏幕位移换算成世界位移的比例：1pt 对应多少米。
    /// 用投影焦距而不是线性近似，和 B 阶段准星的口径保持一致。
    static func metersPerPoint(distance: Float, fieldOfViewDegrees: Float, screenHeight: CGFloat) -> Float {
        guard screenHeight > 0 else { return 0 }
        let focal = Double(screenHeight) / 2 / tan(Double(fieldOfViewDegrees) * .pi / 360)
        return Float(Double(distance) / focal)
    }
}
