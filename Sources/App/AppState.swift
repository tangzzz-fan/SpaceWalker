import TGReduxKit

enum AppRoute: Equatable, Sendable {
    case solarSystem
    case sky
    case tiangong
}

struct AppState: State {
    var route: AppRoute = .solarSystem
    var space = SolarSystemState()
    var flags = FeatureFlags()
}

enum AppAction: Action {
    case appStarted
    case space(SolarSystemAction)
    case route(AppRoute)
    case flagsLoaded(FeatureFlags)
}
