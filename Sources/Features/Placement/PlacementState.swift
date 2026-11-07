import TGReduxKit

struct PlacementState: State {
    var isSurfaceAvailable = false
    var isPlaced = false
    var driftMeters: Float = 0
    var needsReplace = false

    var driftLine: String {
        String(format: "漂移 %.1f cm", driftMeters * 100)
    }
}

enum PlacementAction: Action {
    case surfaceAvailable(Bool)
    case placed
    case driftMeasured(Float)
    case replacePrompted(Bool)
    case reset
}

enum PlacementReducer {
    static func reduce(_ state: inout PlacementState, _ action: PlacementAction) {
        switch action {
        case .surfaceAvailable(let available):
            state.isSurfaceAvailable = available
        case .placed:
            state.isPlaced = true
            state.driftMeters = 0
            state.needsReplace = false
        case .driftMeasured(let drift):
            state.driftMeters = drift
            if PlacementMath.exceedsDrift(drift) {
                state.needsReplace = true
            }
        case .replacePrompted(let needed):
            state.needsReplace = needed
        case .reset:
            state = PlacementState()
        }
    }
}
