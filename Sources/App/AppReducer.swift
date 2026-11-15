import TGReduxKit

func makeAppReducer() -> Reducer<AppState, AppAction> {
    { state, action in
        switch action {
        case .appStarted:
            break
        case .space(let spaceAction):
            SolarSystemReducer.reduce(&state.space, spaceAction)
            if case .select(let body) = spaceAction {
                state.chrome = ChromeState.derive(
                    route: state.route,
                    mode: body == nil ? .normal : .card,
                    selection: body.map(ChromeSelection.body),
                    separation: state.chrome.separation,
                    diagnosticsEnabled: state.chrome.diagnosticsVisible
                )
            }
        case .route(let route):
            state.route = route
            state.chrome = ChromeState.derive(route: route)
        case .chrome(let chromeAction):
            reduceChrome(&state, chromeAction)
        case .flagsLoaded(let flags):
            state.flags = flags
        }
    }
}

private func reduceChrome(_ state: inout AppState, _ action: ChromeAction) {
    switch action {
    case .toggleDiagnostics:
        state.chrome.diagnosticsVisible.toggle()
        state.chrome.debugOverlay = .off
    case .setMode(let mode):
        state.chrome = ChromeState.derive(
            route: state.route,
            mode: mode,
            selection: state.chrome.selection,
            separation: state.chrome.separation,
            diagnosticsEnabled: state.chrome.diagnosticsVisible
        )
    case .select(let selection):
        state.chrome = ChromeState.derive(
            route: state.route,
            mode: state.chrome.mode,
            selection: selection,
            separation: state.chrome.separation,
            diagnosticsEnabled: state.chrome.diagnosticsVisible
        )
    case .setStatus(let detail):
        state.chrome.statusLine.detail = detail
    case .setSeparation(let separation):
        state.chrome = ChromeState.derive(
            route: state.route,
            mode: state.chrome.mode,
            selection: state.chrome.selection,
            separation: separation,
            diagnosticsEnabled: state.chrome.diagnosticsVisible
        )
    case .dismissCard:
        state.chrome = ChromeState.derive(
            route: state.route,
            separation: state.chrome.separation,
            diagnosticsEnabled: state.chrome.diagnosticsVisible
        )
    }
}
