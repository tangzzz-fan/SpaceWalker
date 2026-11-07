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
    /// 实验舱（含非密封后锥段）轴向长度。
    static let labLength: Float = 6.4
    /// 资源舱轴向尺寸。
    static let resourceLength: Float = 3.2
    static let resourceDiameter: Float = 2.775
    /// 对接机构占掉的长度：10.4 − 6.4 − 3.2 = 0.8。
    static let dockingPortLength: Float = 0.8
    /// 电池翼展开后**总跨度**（含舱体），一手数据 18.405 m。单翼长度由此反推。
    static let wingSpan: Float = 18.405
    /// 单翼宽度没有一手数据，取视觉合理值，不进任何界面文案。
    static let wingWidth: Float = 2.5
    static let shenzhouLength: Float = 9.0
    static let shenzhouDiameter: Float = 2.8

    /// 单翼长度 =（总跨度 − 舱体最大直径）/ 2。
    static var wingLength: Float {
        (wingSpan - maxDiameter) / 2
    }
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
    /// 数字全部从常量插值，避免文案与几何各写一份。
    var detail: String {
        switch self {
        case .lab:
            "前段密封舱 + 非密封后锥段 · 轴向 \(TiangongFormat.meters(TiangongModel.labLength))"
        case .resource:
            "后段柱状非密封舱，太阳翼挂这里 · Ø\(TiangongFormat.meters(TiangongModel.resourceDiameter)) × \(TiangongFormat.meters(TiangongModel.resourceLength))"
        case .leftWing, .rightWing:
            "两翼展开总跨度 \(TiangongFormat.meters(TiangongModel.wingSpan))"
        case .shenzhou:
            "对接任务的飞船 · 全长 \(TiangongFormat.meters(TiangongModel.shenzhouLength))"
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

    static let dockingPortZ = labLengthDisplay + TiangongScale.display(TiangongModel.dockingPortLength)

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

    static let shenzhouCenter = SIMD3<Float>(0, 0, dockingPortZ + 0.42)

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
        (TiangongScale.display(TiangongModel.wingSpan),
         TiangongScale.display(TiangongModel.totalLength))
    }
}

/// 拆解位移。沿各自装配轴向外，距离在展示坐标里量。
/// 纯函数：场景只负责把结果搬到实体上，判定与复位都不依赖渲染。
enum TiangongDisassembly {
    static let offset: Float = 0.12

    static func axis(_ id: TiangongModuleID) -> SIMD3<Float> {
        switch id {
        case .lab: SIMD3(0, 0, 1)
        case .resource: SIMD3(0, 0, -1)
        case .leftWing: SIMD3(-1, 0, 0)
        case .rightWing: SIMD3(1, 0, 0)
        case .shenzhou: SIMD3(0, 0, 0)
        }
    }

    static func separatedPosition(_ id: TiangongModuleID) -> SIMD3<Float> {
        TiangongLayout.restPosition(id) + axis(id) * offset
    }

    static func isDismantlable(_ id: TiangongModuleID) -> Bool {
        TiangongModuleID.dismantlable.contains(id)
    }
}

enum TiangongFormat {
    /// 去掉小数尾零的米数：6.400 → "6.4 m"，18.405 → "18.405 m"。
    static func meters(_ value: Float) -> String {
        var text = String(format: "%.3f", value)
        while text.contains("."), text.hasSuffix("0") {
            text.removeLast()
        }
        if text.hasSuffix(".") { text.removeLast() }
        return text + " m"
    }
}
