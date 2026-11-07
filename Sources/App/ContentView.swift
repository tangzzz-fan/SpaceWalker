import SwiftUI
import TGReduxKit

struct ContentView: View {
    @Environment(Store<AppState, AppAction>.self) private var store

    var body: some View {
        Group {
            if store.state.flags.prototypeEnabled {
                PrototypeView()
            } else {
                ContentUnavailableView(
                    "原型未启用",
                    systemImage: "sparkles",
                    description: Text("在 Feature Flag 中开启 spacewalker.prototype")
                )
            }
        }
    }
}
