import Foundation

enum ChromeMode: Equatable, Sendable, CaseIterable {
    case normal
    case card
    case finder
    case tonight
    case asterisms
    case cutaway
    case drawing
    case docking
    case reentry
    case history
}

enum ChromeSelection: Equatable, Sendable {
    case star(String)
    case body(BodyID)
    case module(TiangongModuleID)

    var title: String {
        switch self {
        case .star(let name): name
        case .body(let id): id.rawValue
        case .module(let id): id.title
        }
    }
}

struct ChromeTab: Equatable, Sendable {
    var route: AppRoute
    var title: String
    var isSelected: Bool
}

struct DebugOverlay: Equatable, Sendable {
    var fps: Bool
    var pickProbe: Bool
    var coordinateStatus: Bool

    static let off = DebugOverlay(fps: false, pickProbe: false, coordinateStatus: false)
}

struct ChromeStatusLine: Equatable, Sendable {
    var title: String
    var detail: String
}

enum ChromePrimaryID: Equatable, Sendable, Hashable {
    case skyFind
    case skyLocate
    case skyAlign
    case skyDismiss
    case spaceOverview
    case spaceFocus
    case tiangongDisassemble
    case tiangongToggleSeparation
    case tiangongApproach
    case tiangongExitCutaway
    case tiangongExitDrawing
    case tiangongReentryControl
    case tiangongDismiss
}

struct ChromePrimaryAction: Equatable, Sendable {
    var id: ChromePrimaryID
    var title: String
    var isEnabled: Bool
}

enum ChromeControlID: Equatable, Sendable, Hashable {
    case skyLayers
    case skyTonight
    case skyAttitude
    case skyCategoryStars
    case skyCategoryConstellations
    case skyCategoryAsterisms
    case skyLocateMethod
    case skyCity
    case skyResetTime
    case spacePause
    case spaceRate
    case spaceOrbits
    case tiangongCutaway
    case tiangongDrawing
    case tiangongReentry
    case tiangongInteriorLabels
    case tiangongResetView
    case tiangongFrontView
    case tiangongSideView
    case tiangongTopView
    case tiangongCoarse
    case tiangongFine
    case tiangongHold
    case tiangongHistory
    case tiangongCredits
    case credits
    case history
    case diagnostics
}

struct ChromeControl: Equatable, Sendable {
    var id: ChromeControlID
    var title: String
    var symbol: String
}

struct ChromeInfoCard: Equatable, Sendable {
    var selection: ChromeSelection
    var title: String
}

struct ChromeLabel: Equatable, Sendable {
    var id: String
    var title: String
}

struct ChromeState: Equatable, Sendable {
    var route: AppRoute
    var tabs: [ChromeTab]
    var debugOverlay: DebugOverlay
    var diagnosticsVisible: Bool
    var mode: ChromeMode
    var selection: ChromeSelection?
    var statusLine: ChromeStatusLine
    var primaryAction: ChromePrimaryAction
    var contextControls: [ChromeControl]
    var visibleLabels: [ChromeLabel]
    var infoCard: ChromeInfoCard?

    static func derive(
        route: AppRoute,
        mode: ChromeMode = .normal,
        selection: ChromeSelection? = nil,
        diagnosticsEnabled: Bool = false
    ) -> ChromeState {
        ChromeState(
            route: route,
            tabs: [
                ChromeTab(route: .sky, title: "星图", isSelected: route == .sky),
                ChromeTab(route: .solarSystem, title: "太阳系", isSelected: route == .solarSystem),
                ChromeTab(route: .tiangong, title: "天宫一号", isSelected: route == .tiangong)
            ],
            debugOverlay: .off,
            diagnosticsVisible: diagnosticsEnabled,
            mode: mode,
            selection: selection,
            statusLine: statusLine(route: route, mode: mode, selection: selection),
            primaryAction: primaryAction(route: route, mode: mode),
            contextControls: contextControls(route: route, mode: mode),
            visibleLabels: labels(for: selection),
            infoCard: card(for: selection)
        )
    }

    private static func statusLine(
        route: AppRoute,
        mode: ChromeMode,
        selection: ChromeSelection?
    ) -> ChromeStatusLine {
        switch route {
        case .sky:
            switch mode {
            case .finder:
                return ChromeStatusLine(title: "星图", detail: "搜索恒星、星座或星官")
            case .tonight:
                return ChromeStatusLine(title: "星图", detail: "对齐今夜此刻的真实天空")
            case .card:
                return ChromeStatusLine(title: "星图", detail: "已选中 · \(selection?.title ?? "天体")")
            default:
                return ChromeStatusLine(title: "星图", detail: "姿态跟随 · 转动手机环顾")
            }
        case .solarSystem:
            switch mode {
            case .card:
                return ChromeStatusLine(title: "太阳系", detail: "已选中 · \(selection?.title ?? "天体")")
            default:
                return ChromeStatusLine(title: "太阳系", detail: "行星沿轨道运行")
            }
        case .tiangong:
            switch mode {
            case .cutaway:
                return ChromeStatusLine(title: "天宫一号", detail: "剖面 · 舱内示意")
            case .drawing:
                return ChromeStatusLine(title: "天宫一号", detail: "工程图 · 正视图")
            case .docking:
                return ChromeStatusLine(title: "天宫一号", detail: "交会对接 · 稳定接近")
            case .reentry:
                return ChromeStatusLine(title: "天宫一号", detail: "最后一圈")
            case .card:
                return ChromeStatusLine(title: "天宫一号", detail: "已选中 · \(selection?.title ?? "舱段")")
            default:
                return ChromeStatusLine(title: "天宫一号", detail: "目标飞行器 · 1:\(Int(TiangongScale.ratio)) 展示")
            }
        }
    }

    private static func primaryAction(route: AppRoute, mode: ChromeMode) -> ChromePrimaryAction {
        switch route {
        case .sky:
            switch mode {
            case .card:
                return ChromePrimaryAction(id: .skyLocate, title: "定位", isEnabled: true)
            case .finder:
                return ChromePrimaryAction(id: .skyDismiss, title: "取消", isEnabled: true)
            case .tonight:
                return ChromePrimaryAction(id: .skyAlign, title: "对齐", isEnabled: true)
            case .asterisms, .history:
                return ChromePrimaryAction(id: .skyDismiss, title: "完成", isEnabled: true)
            default:
                return ChromePrimaryAction(id: .skyFind, title: "找星", isEnabled: true)
            }
        case .solarSystem:
            switch mode {
            case .card:
                return ChromePrimaryAction(id: .spaceFocus, title: "聚焦", isEnabled: true)
            default:
                return ChromePrimaryAction(id: .spaceOverview, title: "全览", isEnabled: true)
            }
        case .tiangong:
            switch mode {
            case .card:
                return ChromePrimaryAction(id: .tiangongToggleSeparation, title: "装回", isEnabled: true)
            case .docking:
                return ChromePrimaryAction(id: .tiangongApproach, title: "推进", isEnabled: true)
            case .cutaway:
                return ChromePrimaryAction(id: .tiangongExitCutaway, title: "退出剖面", isEnabled: true)
            case .drawing:
                return ChromePrimaryAction(id: .tiangongExitDrawing, title: "退出工程图", isEnabled: true)
            case .reentry:
                return ChromePrimaryAction(id: .tiangongReentryControl, title: "跳过", isEnabled: true)
            case .history:
                return ChromePrimaryAction(id: .tiangongDismiss, title: "完成", isEnabled: true)
            default:
                return ChromePrimaryAction(id: .tiangongDisassemble, title: "开始拆解", isEnabled: true)
            }
        }
    }

    private static func contextControls(route: AppRoute, mode: ChromeMode) -> [ChromeControl] {
        switch route {
        case .sky:
            switch mode {
            case .finder:
                return [
                    ChromeControl(id: .skyCategoryStars, title: "恒星", symbol: "star"),
                    ChromeControl(id: .skyCategoryConstellations, title: "星座", symbol: "link"),
                    ChromeControl(id: .skyCategoryAsterisms, title: "星官", symbol: "circle.grid.3x3")
                ]
            case .tonight:
                return [
                    ChromeControl(id: .skyLocateMethod, title: "定位", symbol: "location"),
                    ChromeControl(id: .skyCity, title: "城市", symbol: "building.2"),
                    ChromeControl(id: .skyResetTime, title: "重置", symbol: "arrow.counterclockwise")
                ]
            default:
                return [
                    ChromeControl(id: .skyLayers, title: "图层", symbol: "square.3.layers.3d"),
                    ChromeControl(id: .skyTonight, title: "今夜", symbol: "location"),
                    ChromeControl(id: .skyAttitude, title: "姿态", symbol: "gyroscope")
                ]
            }
        case .solarSystem:
            return [
                ChromeControl(id: .spacePause, title: "暂停", symbol: "pause"),
                ChromeControl(id: .spaceRate, title: "流速", symbol: "speedometer"),
                ChromeControl(id: .spaceOrbits, title: "轨道", symbol: "circle.dashed")
            ]
        case .tiangong:
            switch mode {
            case .cutaway:
                return [
                    ChromeControl(id: .tiangongInteriorLabels, title: "舱内标注", symbol: "text.bubble"),
                    ChromeControl(id: .tiangongResetView, title: "复位视角", symbol: "arrow.counterclockwise")
                ]
            case .drawing:
                return [
                    ChromeControl(id: .tiangongFrontView, title: "正视图", symbol: "viewfinder"),
                    ChromeControl(id: .tiangongSideView, title: "侧视图", symbol: "rotate.3d"),
                    ChromeControl(id: .tiangongTopView, title: "俯视图", symbol: "arrow.down.right.and.arrow.up.left")
                ]
            case .docking:
                return [
                    ChromeControl(id: .tiangongCoarse, title: "粗调", symbol: "arrow.up.left"),
                    ChromeControl(id: .tiangongFine, title: "精调", symbol: "scope"),
                    ChromeControl(id: .tiangongHold, title: "保持", symbol: "hand.raised")
                ]
            case .reentry, .history:
                return [
                    ChromeControl(id: .tiangongHistory, title: "史实", symbol: "book.closed"),
                    ChromeControl(id: .tiangongCredits, title: "来源", symbol: "info.circle")
                ]
            default:
                return [
                    ChromeControl(id: .tiangongCutaway, title: "剖面", symbol: "circle.lefthalf.filled"),
                    ChromeControl(id: .tiangongDrawing, title: "工程图", symbol: "ruler"),
                    ChromeControl(id: .tiangongReentry, title: "再入", symbol: "flame")
                ]
            }
        }
    }

    private static func labels(for selection: ChromeSelection?) -> [ChromeLabel] {
        guard case .module(let id)? = selection else { return [] }
        return [ChromeLabel(id: id.rawValue, title: id.title)]
    }

    private static func card(for selection: ChromeSelection?) -> ChromeInfoCard? {
        guard let selection else { return nil }
        return ChromeInfoCard(selection: selection, title: selection.title)
    }
}
