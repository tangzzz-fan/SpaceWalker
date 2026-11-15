import TGReduxKit

enum AppRoute: Equatable, Hashable, Sendable {
    case solarSystem
    case sky
    case tiangong

    static let defaultRoute: AppRoute = .sky
}

struct ChromeTab: Equatable, Sendable {
    var route: AppRoute
    var title: String
    var isSelected: Bool
}

struct DebugOverlay: Equatable, Sendable {
    var fps: Bool
    var pickProbe: Bool
    var coordinateStatus: Bool

    static let off = DebugOverlay(fps: false, pickProbe: false, coordinateStatus: false)
}

enum ChromeAction: Equatable, Sendable {
    case toggleDiagnostics
}

struct ChromeState: Equatable, Sendable {
    var route: AppRoute
    var tabs: [ChromeTab]
    var debugOverlay: DebugOverlay
    var diagnosticsVisible: Bool

    static func derive(route: AppRoute, diagnosticsEnabled: Bool = false) -> ChromeState {
        ChromeState(
            route: route,
            tabs: [
                ChromeTab(route: .sky, title: "星图", isSelected: route == .sky),
                ChromeTab(route: .solarSystem, title: "太阳系", isSelected: route == .solarSystem),
                ChromeTab(route: .tiangong, title: "天宫一号", isSelected: route == .tiangong)
            ],
            debugOverlay: .off,
            diagnosticsVisible: diagnosticsEnabled
        )
    }
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
