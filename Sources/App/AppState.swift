import TGReduxKit

typealias AppRoute = ScaleLevel

extension ScaleLevel {
    static var solarSystem: ScaleLevel { .solar }
    static var defaultRoute: ScaleLevel { .defaultLevel }
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
    var savedSelections: [ScaleLevel: ChromeSelection] = [:]
    var transition: ScaleTransitionRequest?
    var transitionToken = 0
    var overviewToken = 0
    var attitudeRestoreNoticeToken = 0
    var hasShownAttitudeRestoreNotice = false

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

struct ScaleTransitionRequest: Equatable, Sendable {
    var from: ScaleLevel
    var to: ScaleLevel
    var token: Int
}

enum AppAction: Action {
    case appStarted
    case space(SolarSystemAction)
    case route(AppRoute)
    case descend(ScaleLevel)
    case ascend
    case overview
    case chrome(ChromeAction)
    case flagsLoaded(FeatureFlags)
}
