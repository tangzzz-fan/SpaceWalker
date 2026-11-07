import TGReduxKit

func makeAppReducer() -> Reducer<AppState, AppAction> {
    { state, action in
        switch action {
        case .appStarted:
            break
        case .prototype(let prototypeAction):
            PrototypeReducer.reduce(&state.prototype, prototypeAction)
        case .session(let sessionAction):
            SessionReducer.reduce(&state.session, sessionAction)
        case .placement(let placementAction):
            PlacementReducer.reduce(&state.placement, placementAction)
        case .flagsLoaded(let flags):
            state.flags = flags
        }
    }
}
