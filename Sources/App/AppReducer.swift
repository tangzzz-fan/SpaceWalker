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
            switch spaceAction {
            case .enterOverview:
                if state.space.narrative.isPlaying {
                    state.chrome.statusLine.detail = ScaleNarrative.rulerText
                }
            case .finishScaleNarrative:
                state.chrome.statusLine.detail = SolarSystemState.statusDetail(
                    days: state.space.days,
                    isPaused: state.space.isPaused,
                    rate: state.space.rateInRange
                )
            default:
                break
            }
        case .route(let route):
            navigate(&state, to: route)
        case .descend(let target):
            guard state.route.canDescend(to: target) else { break }
            if target == .solar, case .body(let focused)? = state.chrome.selection {
                state.space.selected = focused
                state.space.days = 0
                state.space.isPaused = true
            }
            navigate(&state, to: target)
        case .ascend:
            guard let target = state.route.above else { break }
            navigate(&state, to: target)
        case .overview:
            state.overviewToken += 1
        case .chrome(let chromeAction):
            reduceChrome(&state, chromeAction)
        case .flagsLoaded(let flags):
            state.flags = flags
            recomputeChrome(&state)
        }
    }
}

private func navigate(_ state: inout AppState, to target: ScaleLevel) {
    let source = state.route
    guard target != source,
          source.canAscend(to: target) || source.canDescend(to: target)
    else { return }
    if let selection = state.chrome.selection {
        state.savedSelections[source] = selection
    } else {
        state.savedSelections[source] = nil
    }
    let restored = state.savedSelections[target]
    state.route = target
    state.chrome = ChromeState.derive(
        route: target,
        mode: restored == nil ? .normal : .card,
        selection: restored,
        diagnosticsEnabled: false,
        theme: state.chrome.theme,
        reentryUnlocked: state.chrome.reentryUnlocked,
        cultureEnabled: state.flags.cultureEnabled
    )
    state.transitionToken += 1
    state.transition = ScaleTransitionRequest(from: source, to: target, token: state.transitionToken)
    if target == .sky, !state.hasShownAttitudeRestoreNotice {
        state.hasShownAttitudeRestoreNotice = true
        state.attitudeRestoreNoticeToken += 1
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
    tonightAligned: Bool? = nil,
    reentryUnlocked: Bool? = nil,
    dockingFine: Bool? = nil,
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
        theme: theme ?? state.chrome.theme,
        tonightAligned: tonightAligned ?? state.chrome.tonightAligned,
        reentryUnlocked: reentryUnlocked ?? state.chrome.reentryUnlocked,
        dockingFine: dockingFine ?? state.chrome.dockingFine,
        cultureEnabled: state.flags.cultureEnabled
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
    case .setTonight(let aligned):
        recomputeChrome(&state, tonightAligned: aligned)
    case .setReentryUnlocked(let unlocked):
        recomputeChrome(&state, reentryUnlocked: unlocked)
    case .setDockingFine(let fine):
        recomputeChrome(&state, dockingFine: fine)
    case .dismissCard:
        recomputeChrome(&state, reset: true)
    }
}
