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
            state.chrome = ChromeState.derive(route: route)
        case .chrome(let chromeAction):
            switch chromeAction {
            case .toggleDiagnostics:
                state.chrome.diagnosticsVisible.toggle()
                state.chrome.debugOverlay = .off
            }
        case .flagsLoaded(let flags):
            state.flags = flags
        }
    }
}
