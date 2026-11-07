import SwiftUI
import TGReduxKit

struct ContentView: View {
    @Environment(Store<AppState, AppAction>.self) private var store

    var body: some View {
        Group {
            if store.state.flags.prototypeEnabled {
                PrototypeView()
            } else {
                SessionView()
            }
        }
    }
}
