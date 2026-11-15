import TGFeatureFlag
import TGReduxKit

/// 环境变量优先于快照：验收深档内容时不用改远端配置。
private func resolved(
    _ feature: AppFeature,
    _ snapshot: FeatureFlagSnapshot,
    _ environment: [String: String]
) -> Bool {
    feature.override(environment: environment) ?? snapshot.isEnabled(feature)
}

func makeFlagsMiddleware(resolver: FeatureFlagResolver) -> Middleware<AppState, AppAction> {
    { _, action, next in
        let base = next(action)

        guard case .appStarted = action else { return base }

        return .merge(base, .task {
            _ = try? await resolver.refresh()
            let snapshot = resolver.snapshot(for: AppFeature.allCases)
            let environment = LaunchMode.environment()
            let line = String(
                format: "app.flags culture=%d deep=%d",
                resolved(.contentCulture, snapshot, environment) ? 1 : 0,
                resolved(.contentDeep, snapshot, environment) ? 1 : 0
            )
            await MainActor.run { SessionLog.append(line) }
            return .flagsLoaded(
                FeatureFlags(
                    cultureEnabled: resolved(.contentCulture, snapshot, environment),
                    deepEnabled: resolved(.contentDeep, snapshot, environment)
                )
            )
        })
    }
}
