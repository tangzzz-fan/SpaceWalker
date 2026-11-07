import Foundation
import SwiftUI
import TGFeatureFlag
import TGReduxKit

@main
struct SpaceWalkerApp: App {
    @State private var store: Store<AppState, AppAction>

    init() {
        _ = AppClock.launchUptime
        SessionLog.reset(context: SessionLog.deviceContext())

        let resolver = FeatureFlagResolver()
        let features = LaunchMode.enabledFeatures(environment: ProcessInfo.processInfo.environment)
        resolver.register(provider: LocalProvider(enabledFeatures: features))

        _store = State(
            initialValue: Store(
                initialState: AppState(
                    route: LaunchMode.initialRoute(environment: ProcessInfo.processInfo.environment)
                ),
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
