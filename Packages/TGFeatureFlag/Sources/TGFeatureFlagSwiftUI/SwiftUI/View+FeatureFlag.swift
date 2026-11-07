import SwiftUI
import TGFeatureFlagCore

public extension View {
    /// Injects the `FeatureFlagService` into the view hierarchy.
    /// Call this at the root of your app (e.g., inside `WindowGroup`).
    ///
    /// Injected twice on purpose: `.environment(_:)` makes the service available to
    /// `@Environment(FeatureFlagService.self)` and Observation-based views, while the keyed
    /// entry gives `FeatureGate` a *non-trapping* lookup so the same gate type also works in
    /// snapshot-only (Redux) hierarchies where no service exists.
    func featureFlagService(_ service: FeatureFlagService) -> some View {
        self
            .environment(service)
            .environment(\.featureFlagService, service)
    }
}
