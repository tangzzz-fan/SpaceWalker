import TGReduxKit

struct AppState: State {
    var prototype = PrototypeState()
    var flags = FeatureFlags()
}

enum AppAction: Action {
    case appStarted
    case prototype(PrototypeAction)
    case flagsLoaded(FeatureFlags)
}
