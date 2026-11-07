import TGReduxKit

struct AppState: State {
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
    case flagsLoaded(FeatureFlags)
}
