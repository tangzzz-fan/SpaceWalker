import TGReduxKit

struct AppState: State {
    var prototype = PrototypeState()
    var session = SessionState()
    var flags = FeatureFlags()
}

enum AppAction: Action {
    case appStarted
    case prototype(PrototypeAction)
    case session(SessionAction)
    case flagsLoaded(FeatureFlags)
}
