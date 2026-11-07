import TGReduxKit

enum AppRoute: Equatable, Sendable {
    case solarSystem
    case sky
}

struct AppState: State {
    var route: AppRoute = .solarSystem
    var prototype = PrototypeState()
    var session = SessionState()
    var placement = PlacementState()
    var permission = PermissionState()
    var space = SolarSystemState()
    var flags = FeatureFlags()
}

enum AppAction: Action {
    case appStarted
    case prototype(PrototypeAction)
    case session(SessionAction)
    case placement(PlacementAction)
    case permission(PermissionAction)
    case space(SolarSystemAction)
    case route(AppRoute)
    case flagsLoaded(FeatureFlags)
}
