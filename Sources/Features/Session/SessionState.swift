import TGReduxKit

struct SessionState: State {
    var phase: SessionPhase = .idle
    var requirements = SessionPlan.m0
    var unavailability = SessionUnavailability()
}

enum SessionAction: Action {
    case phaseChanged(SessionPhase)
    case reported(SessionOutcome)
}

enum SessionReducer {
    static func reduce(_ state: inout SessionState, _ action: SessionAction) {
        switch action {
        case .phaseChanged(let phase):
            state.phase = phase
        case .reported(let outcome):
            state.requirements = outcome.requirements
            state.unavailability = outcome.unavailability
            if !outcome.isUsable {
                state.phase = .failed
            }
        }
    }
}
