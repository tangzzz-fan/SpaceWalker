import TGFeatureFlag
import TGReduxKit

func makeFlagsMiddleware(resolver: FeatureFlagResolver) -> Middleware<AppState, AppAction> {
    { _, action, next in
        let base = next(action)

        guard case .appStarted = action else { return base }

        return .merge(base, .task {
            _ = try? await resolver.refresh()
            let snapshot = resolver.snapshot(for: AppFeature.allCases)
            return .flagsLoaded(
                FeatureFlags(
                    prototypeEnabled: snapshot.isEnabled(AppFeature.prototype)
                )
            )
        })
    }
}
