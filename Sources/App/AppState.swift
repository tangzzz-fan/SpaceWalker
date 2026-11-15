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
        diagnosticsEnabled: Bool = false
    ) {
        self.route = route
        self.chrome = ChromeState.derive(route: route, diagnosticsEnabled: diagnosticsEnabled)
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
