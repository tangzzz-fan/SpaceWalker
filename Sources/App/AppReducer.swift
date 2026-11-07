import TGReduxKit

func makeAppReducer() -> Reducer<AppState, AppAction> {
    { state, action in
        switch action {
        case .appStarted:
            break
        case .prototype(let prototypeAction):
            PrototypeReducer.reduce(&state.prototype, prototypeAction)
        case .flagsLoaded(let flags):
            state.flags = flags
        }
    }
}
