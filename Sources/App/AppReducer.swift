import TGReduxKit

func makeAppReducer() -> Reducer<AppState, AppAction> {
    { state, action in
        switch action {
        case .appStarted:
            break
        case .space(let spaceAction):
            SolarSystemReducer.reduce(&state.space, spaceAction)
        case .route(let route):
            state.route = route
        case .flagsLoaded(let flags):
            state.flags = flags
        }
    }
}
