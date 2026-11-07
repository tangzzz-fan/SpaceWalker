import Foundation

/// 三任务串联：拆解 → 装配 → 对接。
/// 状态机是纯值，失败原因直接引用判定输出，不另写一套文案。
enum TiangongMission {
    enum Phase: String, Equatable, Sendable {
        case disassembly
        case assembly
        case docking
        case complete

        var title: String {
            switch self {
            case .disassembly: "拆解"
            case .assembly: "装配"
            case .docking: "对接"
            case .complete: "已全部完成"
            }
        }

        var ordinal: Int {
            switch self {
            case .disassembly: 1
            case .assembly: 2
            case .docking: 3
            case .complete: 3
            }
        }
    }

    struct State: Equatable, Sendable {
        var phase: Phase = .disassembly
        var separatedCount = 0
        var failure: String?

        /// 拆解阶段的目标：四个模块全部离位。
        var disassemblyTarget = TiangongModuleID.dismantlable.count
    }

    static func start() -> State {
        State()
    }

    /// 分离状态变化后推进。拆满四个进装配，全部装回进对接。
    static func separated(_ state: State, count: Int) -> State {
        var next = state
        next.separatedCount = count
        switch state.phase {
        case .disassembly where count >= state.disassemblyTarget:
            next.phase = .assembly
        case .assembly where count == 0 && state.separatedCount > 0:
            next.phase = .docking
        default:
            break
        }
        return next
    }

    /// 对接结果。失败留在对接阶段并记原因，成功即完成。
    static func docking(_ state: State, outcome: TiangongDocking.Outcome) -> State {
        guard state.phase == .docking else { return state }
        var next = state
        switch outcome {
        case .docked:
            next.phase = .complete
            next.failure = nil
        case .failed(let failure):
            next.failure = failure.message
        default:
            break
        }
        return next
    }

    /// 重玩回到第一步；分离与对接状态由调用方一并清空。
    static func replay(_ state: State) -> State {
        var next = start()
        next.disassemblyTarget = state.disassemblyTarget
        return next
    }

    static func summary(_ state: State) -> String {
        switch state.phase {
        case .disassembly:
            "拆解 \(state.separatedCount)/\(state.disassemblyTarget)"
        case .assembly:
            "装配 已装回 \(state.disassemblyTarget - state.separatedCount)/\(state.disassemblyTarget)"
        case .docking:
            state.failure.map { "对接 · \($0)" } ?? "对接"
        case .complete:
            "三步全部完成"
        }
    }
}
