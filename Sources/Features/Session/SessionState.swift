import TGReduxKit

struct SessionState: State {
    var phase: SessionPhase = .idle
    var requirements = SessionPlan.m0
    var unavailability = SessionUnavailability()
    var startedInMilliseconds: Int?

    var diagnosticLine: String? {
        guard let startedInMilliseconds else { return nil }
        return "\(startedInMilliseconds)ms · anchors \(requirements.anchors.count)"
            + " · scene \(requirements.sceneUnderstanding.count)"
            + " · unavailable \(unavailability.anchors.count)"
    }
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
            state.startedInMilliseconds = outcome.startedInMilliseconds
            if !outcome.isUsable {
                state.phase = .failed
            }
        }
    }
}
