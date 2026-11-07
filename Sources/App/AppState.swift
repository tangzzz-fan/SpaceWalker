import TGReduxKit

struct AppState: State {
    var prototype = PrototypeState()
    var session = SessionState()
    var placement = PlacementState()
    var permission = PermissionState()
    var flags = FeatureFlags()
}

enum AppAction: Action {
    case appStarted
    case prototype(PrototypeAction)
    case session(SessionAction)
    case placement(PlacementAction)
    case permission(PermissionAction)
    case flagsLoaded(FeatureFlags)
}
