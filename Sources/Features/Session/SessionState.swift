import TGReduxKit

struct SessionState: State {
    var phase: SessionPhase = .idle
    var requirements = SessionPlan.m0
    var unavailability = SessionUnavailability()
    var matrix = CapabilityMatrix.full
    var startedInMilliseconds: Int?

    var diagnosticLine: String? {
        guard let startedInMilliseconds else { return nil }
        return "\(startedInMilliseconds)ms · anchors \(requirements.anchors.count)"
            + " · scene \(requirements.sceneUnderstanding.count)"
            + " · unavailable \(unavailableSummary)"
    }

    private var unavailableSummary: String {
        let anchors = unavailability.anchors.map(\.rawValue).sorted()
        let scene = unavailability.sceneUnderstanding.map(\.rawValue).sorted()
        let items = anchors + scene
        return items.isEmpty ? "0" : items.joined(separator: "+")
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
            state.matrix = CapabilityMatrixBuilder.make(from: outcome)
            state.startedInMilliseconds = outcome.startedInMilliseconds
            if !outcome.isUsable {
                state.phase = .failed
            }
        }
    }
}
