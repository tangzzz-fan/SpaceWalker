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

struct ChromeState: Equatable, Sendable {
    var route: AppRoute
    var tabs: [ChromeTab]

    static func derive(route: AppRoute) -> ChromeState {
        ChromeState(
            route: route,
            tabs: [
                ChromeTab(route: .sky, title: "星图", isSelected: route == .sky),
                ChromeTab(route: .solarSystem, title: "太阳系", isSelected: route == .solarSystem),
                ChromeTab(route: .tiangong, title: "天宫一号", isSelected: route == .tiangong)
            ]
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
        flags: FeatureFlags = FeatureFlags()
    ) {
        self.route = route
        self.chrome = ChromeState.derive(route: route)
        self.space = space
        self.flags = flags
    }
}

enum AppAction: Action {
    case appStarted
    case space(SolarSystemAction)
    case route(AppRoute)
    case flagsLoaded(FeatureFlags)
}
