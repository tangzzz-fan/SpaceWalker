import TGReduxKit

enum AppRoute: Equatable, Hashable, Sendable {
    case solarSystem
    case sky
    case tiangong

    static let defaultRoute: AppRoute = .sky
}

enum ChromeAction: Equatable, Sendable {
    case toggleDiagnostics
    case setMode(ChromeMode)
    case select(ChromeSelection?)
    case setStatus(String)
    case setSeparation(Set<String>)
    case setTheme(ChromeTheme)
    case setTonight(Bool)
    case setReentryUnlocked(Bool)
    case setDockingFine(Bool)
    case dismissCard
}

struct AppState: State {
    var route: AppRoute
    var chrome: ChromeState
    var space: SolarSystemState
    var flags: FeatureFlags

    init(
        route: AppRoute = AppRoute.defaultRoute,
        space: SolarSystemState = SolarSystemState(),
        flags: FeatureFlags = FeatureFlags(),
        diagnosticsEnabled: Bool = false,
        theme: ChromeTheme = .dark
    ) {
        self.route = route
        self.chrome = ChromeState.derive(
            route: route,
            diagnosticsEnabled: diagnosticsEnabled,
            theme: theme
        )
        self.space = space
        self.flags = flags
    }
}

enum AppAction: Action {
    case appStarted
    case space(SolarSystemAction)
    case route(AppRoute)
    case chrome(ChromeAction)
    case flagsLoaded(FeatureFlags)
}
