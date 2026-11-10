import Foundation

/// 「最后一圈」：轨道衰减 → 气动加热 → 结构解体 → 史实卡。
///
/// 纯值状态机。渲染只读 `progress(_:)` 的输出，不自己算时间——
/// 否则「跳过」与「重看」会各自维护一份相位，对不上。
enum TiangongReentry {
    enum Phase: String, Equatable, Sendable {
        case idle
        case coast
        case heating
        case breakup
        case card

        var isFlight: Bool {
            switch self {
            case .coast, .heating, .breakup: true
            case .idle, .card: false
            }
        }
    }

    struct State: Equatable, Sendable {
        var phase: Phase = .idle
        var elapsed: TimeInterval = 0
    }

    /// 三拍时长，合计 20 s，落在 FR-C-11 的 18–22 s。
    static let coastDuration: TimeInterval = 7.5
    static let heatingDuration: TimeInterval = 6
    static let breakupDuration: TimeInterval = 6.5
    static var flightDuration: TimeInterval {
        coastDuration + heatingDuration + breakupDuration
    }

    struct Progress: Equatable, Sendable {
        var coast: Float = 0
        var heat: Float = 0
        var breakup: Float = 0
        /// 每个模块的不透明度。解体阶段按「先翼、后舱段」依次归零。
        var alphas: [TiangongModuleID: Float] = [:]
    }

    static func start() -> State {
        State(phase: .coast, elapsed: 0)
    }

    static func step(_ state: State, delta: TimeInterval) -> State {
        guard state.phase.isFlight else { return state }
        let elapsed = min(state.elapsed + max(delta, 0), flightDuration)
        return State(phase: phase(at: elapsed), elapsed: elapsed)
    }

    /// 跳过直接落到史实卡。飞行段内任何时刻都只差一步。
    static func skip(_ state: State) -> State {
        guard state.phase != .idle else { return state }
        return State(phase: .card, elapsed: flightDuration)
    }

    static func phase(at elapsed: TimeInterval) -> Phase {
        if elapsed >= flightDuration { return .card }
        if elapsed < coastDuration { return .coast }
        if elapsed < coastDuration + heatingDuration { return .heating }
        return .breakup
    }

    static func progress(_ state: State) -> Progress {
        guard state.phase != .idle else { return Progress() }
        let coast = clamp(state.elapsed / coastDuration)
        let heat = clamp((state.elapsed - coastDuration) / heatingDuration)
        let breakup = clamp(
            (state.elapsed - coastDuration - heatingDuration) / breakupDuration
        )
        return Progress(coast: coast, heat: heat, breakup: breakup, alphas: alphas(at: breakup))
    }

    /// 淡出顺序：两翼 → 资源舱 → 实验舱 → 神舟。
    /// 每个部件有自己的窗口，窗口之间重叠，看起来是「一段接一段散开」而不是五个同时消失。
    static func alphas(at breakup: Float) -> [TiangongModuleID: Float] {
        let t = clamp(breakup)
        return [
            .leftWing: fade(t, from: 0.00, to: 0.35),
            .rightWing: fade(t, from: 0.00, to: 0.35),
            .resource: fade(t, from: 0.25, to: 0.58),
            .lab: fade(t, from: 0.45, to: 0.78),
            .shenzhou: fade(t, from: 0.65, to: 1.00),
        ]
    }

    /// 解锁条件：三任务全部完成，且看过任务里程碑（070 已降级为史实面板里的一张卡）。
    static func isUnlocked(mission: TiangongMission.State, readMilestones: Bool) -> Bool {
        mission.phase == .complete && readMilestones
    }

    static func caption(_ phase: Phase) -> String? {
        switch phase {
        case .idle, .card: nil
        case .coast: "轨道高度衰减"
        case .heating: "再入大气层 · 气动加热"
        case .breakup: "结构解体"
        }
    }

    private static func clamp(_ value: Double) -> Float {
        clamp(Float(value))
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private static func fade(_ t: Float, from: Float, to: Float) -> Float {
        guard to > from else { return t >= to ? 0 : 1 }
        return 1 - clamp((t - from) / (to - from))
    }
}
