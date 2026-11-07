import SwiftUI
import TGFeatureFlag
import TGReduxKit

@main
struct SpaceWalkerApp: App {
    @State private var store: Store<AppState, AppAction>

    init() {
        let resolver = FeatureFlagResolver()
        resolver.register(provider: LocalProvider(enabledFeatures: [AppFeature.prototype]))

        _store = State(
            initialValue: Store(
                initialState: AppState(),
                reducer: makeAppReducer(),
                middlewares: [makeFlagsMiddleware(resolver: resolver)]
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .provideStore(store)
                .task {
                    store.dispatch(.appStarted)
                }
        }
    }
}
