import SwiftUI
import TGReduxKit

struct ContentView: View {
    @Environment(Store<AppState, AppAction>.self) private var store

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
                SpaceView()
            }
        }
    }
}
