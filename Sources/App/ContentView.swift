import SwiftUI
import TGReduxKit

struct ContentView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    @State private var skySession = SkySession()
    @State private var tiangongSession = TiangongSession()

    var body: some View {
        Group {
            switch store.state.route {
            case .solarSystem:
                SpaceView()
            case .sky:
                SkyView(session: skySession)
            case .tiangong:
                TiangongView(session: tiangongSession)
            }
        }
    }
}
