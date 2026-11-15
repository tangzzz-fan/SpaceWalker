import TGReduxKit

func makeAppReducer() -> Reducer<AppState, AppAction> {
    { state, action in
        switch action {
        case .appStarted:
            break
        case .space(let spaceAction):
            SolarSystemReducer.reduce(&state.space, spaceAction)
            if case .select(let body) = spaceAction {
                recomputeChrome(
                    &state,
                    mode: body == nil ? .normal : .card,
                    selection: body.map(ChromeSelection.body),
                    clearSelection: body == nil
                )
            }
        case .route(let route):
            state.route = route
            recomputeChrome(&state, diagnosticsEnabled: false, reset: true)
        case .chrome(let chromeAction):
            reduceChrome(&state, chromeAction)
        case .flagsLoaded(let flags):
            state.flags = flags
        }
    }
}

private func recomputeChrome(
    _ state: inout AppState,
    mode: ChromeMode? = nil,
    selection: ChromeSelection? = nil,
    clearSelection: Bool = false,
    separation: Set<String>? = nil,
    diagnosticsEnabled: Bool? = nil,
    theme: ChromeTheme? = nil,
    reset: Bool = false
) {
    let nextSelection: ChromeSelection?
    if reset || clearSelection {
        nextSelection = nil
    } else {
        nextSelection = selection ?? state.chrome.selection
    }
    state.chrome = ChromeState.derive(
        route: state.route,
        mode: reset ? .normal : (mode ?? state.chrome.mode),
        selection: nextSelection,
        separation: reset ? [] : (separation ?? state.chrome.separation),
        diagnosticsEnabled: diagnosticsEnabled ?? state.chrome.diagnosticsVisible,
        theme: theme ?? state.chrome.theme
    )
}

private func reduceChrome(_ state: inout AppState, _ action: ChromeAction) {
    switch action {
    case .toggleDiagnostics:
        state.chrome.diagnosticsVisible.toggle()
        state.chrome.debugOverlay = .off
    case .setMode(let mode):
        recomputeChrome(&state, mode: mode)
    case .select(let selection):
        recomputeChrome(&state, selection: selection, clearSelection: selection == nil)
    case .setStatus(let detail):
        state.chrome.statusLine.detail = detail
    case .setSeparation(let separation):
        recomputeChrome(&state, separation: separation)
    case .setTheme(let theme):
        recomputeChrome(&state, theme: theme)
    case .dismissCard:
        recomputeChrome(&state, reset: true)
    }
}
