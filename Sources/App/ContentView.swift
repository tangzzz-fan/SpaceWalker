import SwiftUI
import TGReduxKit

struct ContentView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    @State private var skySession = SkySession()
    @State private var tiangongSession = TiangongSession()
    @State private var actions = ChromeActionRegistry()

    var body: some View {
        Group {
            switch store.state.route {
            case .solarSystem:
                SpaceView(actions: actions)
            case .sky:
                SkyView(actions: actions, session: skySession)
            case .tiangong:
                TiangongView(actions: actions, session: tiangongSession)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ChromeStatusBar(status: store.state.chrome.statusLine, actions: actions)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChromeBottomBar(actions: actions)
        }
        .sheet(isPresented: diagnosticsBinding) {
            ChromeDiagnosticsSheet()
        }
        .preferredColorScheme(store.state.chrome.theme == .dark ? .dark : .light)
    }

    private var diagnosticsBinding: Binding<Bool> {
        Binding(
            get: { store.state.chrome.diagnosticsVisible },
            set: { presented in
                guard !presented, store.state.chrome.diagnosticsVisible else { return }
                store.dispatch(.chrome(.toggleDiagnostics))
            }
        )
    }
}
