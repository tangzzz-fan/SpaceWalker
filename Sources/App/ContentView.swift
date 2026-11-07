import SwiftUI
import TGReduxKit

struct ContentView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    @State private var skySession = SkySession()

    private var mode: LaunchMode.AppMode {
        LaunchMode.mode(environment: ProcessInfo.processInfo.environment)
    }

    var body: some View {
        Group {
            switch mode {
            case .prototype:
                PrototypeView()
            case .ar:
                SessionView()
            case .space:
                switch store.state.route {
                case .solarSystem:
                    SpaceView()
                case .sky:
                    SkyView(session: skySession)
                }
            }
        }
    }
}
