import Foundation
import simd

/// 1:20 展示尺度。所有真实尺寸都从这里过一遍，界面与几何都不许自己除。
enum TiangongScale {
    static let ratio: Float = 20

    static func display(_ realMeters: Float) -> Float {
        realMeters / ratio
    }

    static func real(_ displayMeters: Float) -> Float {
        displayMeters * ratio
    }
}

/// 几何参数，不是史实条目。
///
/// 全长 10.4m 与最大直径 3.35m 是公开数据；两舱分段长度是**视觉分配**，
/// 没有一手来源，因此不进史实卡、界面也不标这两个数字。
enum TiangongModel {
    static let totalLength: Float = 10.4
    static let maxDiameter: Float = 3.35
    static let labLength: Float = 6.2
    static let resourceLength: Float = 4.2
    static let resourceDiameter: Float = 2.8
    static let wingLength: Float = 6.0
    static let wingWidth: Float = 2.0
    static let shenzhouLength: Float = 9.0
    static let shenzhouDiameter: Float = 2.8
}

enum TiangongModuleID: String, CaseIterable, Equatable, Sendable, Identifiable {
    case lab
    case resource
    case leftWing
    case rightWing
    case shenzhou

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lab: "实验舱"
        case .resource: "资源舱"
        case .leftWing, .rightWing: "太阳翼"
        case .shenzhou: "神舟飞船"
        }
    }

    /// 可拆解的模块（PRD FR-C-02）；神舟属于对接任务，不参与拆装。
    static let dismantlable: [TiangongModuleID] = [.lab, .resource, .leftWing, .rightWing]

    /// 卡片文案放在模型层，便于「禁词扫描」这类测试直接遍历。
    var detail: String {
        switch self {
        case .lab:
            "前段舱体，前端为对接口 · 真实长约 6.2 m"
        case .resource:
            "后段舱体，太阳翼挂在这里 · 真实长约 4.2 m"
        case .leftWing, .rightWing:
            "单翼真实约 6.0 m × 2.0 m"
        case .shenzhou:
            "对接任务的飞船 · 全长约 9.0 m"
        }
    }
}

/// 装配位姿：展示坐标（米）。沿 +Z 指向飞行方向，太阳翼沿 ±X 展开。
struct TiangongLayout {
    static let labLengthDisplay = TiangongScale.display(TiangongModel.labLength)
    static let resourceLengthDisplay = TiangongScale.display(TiangongModel.resourceLength)

    /// 两舱首尾相接于 z = 0：实验舱在前（+Z），资源舱在后（−Z）。
    static let labCenter = SIMD3<Float>(0, 0, labLengthDisplay / 2)
    static let resourceCenter = SIMD3<Float>(0, 0, -resourceLengthDisplay / 2)

    static let dockingPortZ = labLengthDisplay

    /// 整机（含待对接的神舟）包围盒中心。相机绕它转，否则模型会偏出画面。
    static let center: SIMD3<Float> = {
        let minZ = -resourceLengthDisplay
        let maxZ = shenzhouCenter.z + TiangongScale.display(TiangongModel.shenzhouLength) / 2
        return SIMD3(0, 0, (minZ + maxZ) / 2)
    }()

    static func wingCenter(_ id: TiangongModuleID) -> SIMD3<Float> {
        let halfWidth = TiangongScale.display(TiangongModel.maxDiameter) / 2
        let wingLength = TiangongScale.display(TiangongModel.wingLength)
        let x = halfWidth + wingLength / 2
        return SIMD3(id == .leftWing ? -x : x, 0, resourceCenter.z)
    }

    static let shenzhouCenter = SIMD3<Float>(0, 0, dockingPortZ + 0.35)

    static func restPosition(_ id: TiangongModuleID) -> SIMD3<Float> {
        switch id {
        case .lab: labCenter
        case .resource: resourceCenter
        case .leftWing, .rightWing: wingCenter(id)
        case .shenzhou: shenzhouCenter
        }
    }

    /// 整机在 X/Z 上的包围盒，用于「落在 1m 桌面内」的断言。
    static var footprint: (width: Float, length: Float) {
        let wingTip = abs(wingCenter(.leftWing).x) + TiangongScale.display(TiangongModel.wingLength) / 2
        let length = TiangongScale.display(TiangongModel.totalLength)
        return (wingTip * 2, length)
    }
}
