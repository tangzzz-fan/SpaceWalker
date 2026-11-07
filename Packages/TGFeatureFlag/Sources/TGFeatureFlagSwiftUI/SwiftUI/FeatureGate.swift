import SwiftUI
import TGFeatureFlagCore

/// An optional lookup for the environment service.
///
/// `@Environment(FeatureFlagService.self)` traps at runtime when the value is missing, which
/// makes it unusable in a view that must also support the snapshot-driven (Redux) mode where
/// no service exists. This key degrades to `nil` instead.
private struct FeatureFlagServiceEnvironmentKey: EnvironmentKey {
    static let defaultValue: FeatureFlagService? = nil
}

public extension EnvironmentValues {
    /// The feature flag service, when one has been injected.
    var featureFlagService: FeatureFlagService? {
        get { self[FeatureFlagServiceEnvironmentKey.self] }
        set { self[FeatureFlagServiceEnvironmentKey.self] = newValue }
    }
}

/// A container view that conditionally displays content based on a feature flag.
///
/// Two ways to supply the value, matching the two supported modes:
///
/// - **Snapshot** (Redux / TGReduxKit): pass the snapshot held by the Store. The Store stays
///   the single source of truth.
/// - **Service** (non-Redux): inject `FeatureFlagService` with `.featureFlagService(_:)` and
///   omit the snapshot. The gate observes the service, so it re-renders when flags change.
///
/// If neither is supplied the gate falls back to the flag's default value rather than
/// trapping, and reports the mistake in debug builds.
///
/// The key must resolve to `Bool`: gating a view on a string configuration value is
/// meaningless, so it is rejected at compile time.
public struct FeatureGate<F: TypedFeatureFlag, Content: View, Fallback: View>: View
where F.Value == Bool {

    private let feature: F
    private let snapshot: FeatureFlagSnapshot?
    private let content: () -> Content
    private let fallback: () -> Fallback

    @Environment(\.featureFlagService) private var service

    /// Creates a gate driven by an injected snapshot.
    public init(
        _ feature: F,
        snapshot: FeatureFlagSnapshot,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder fallback: @escaping () -> Fallback
    ) {
        self.feature = feature
        self.snapshot = snapshot
        self.content = content
        self.fallback = fallback
    }

    /// Creates a gate driven by `FeatureFlagService` in the environment.
    public init(
        _ feature: F,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder fallback: @escaping () -> Fallback
    ) {
        self.feature = feature
        self.snapshot = nil
        self.content = content
        self.fallback = fallback
    }

    public var body: some View {
        if isEnabled {
            content()
        } else {
            fallback()
        }
    }

    private var isEnabled: Bool {
        Self.resolvesEnabled(feature, snapshot: snapshot, service: service)
    }

    /// The gate's decision, factored out so the precedence rule is testable without
    /// rendering a view.
    ///
    /// An explicit snapshot wins over the environment service: passing a snapshot is a
    /// deliberate statement that this view reads the Store, and silently preferring a
    /// service in the environment would reintroduce the second source of truth the two-mode
    /// design exists to prevent.
    static func resolvesEnabled(
        _ feature: F,
        snapshot: FeatureFlagSnapshot?,
        service: FeatureFlagService?
    ) -> Bool {
        if let snapshot {
            return snapshot.isEnabled(feature)
        }

        guard let service else {
            assertionFailure(
                """
                FeatureGate("\(feature.lookupKey)") has neither a snapshot nor a \
                FeatureFlagService in the environment. Pass `snapshot:` or apply \
                `.featureFlagService(_:)` at the root of the hierarchy.
                """
            )
            return feature.defaultValue.boolValue ?? false
        }

        return service.isEnabled(feature)
    }
}

public extension FeatureGate where Fallback == EmptyView {
    /// Convenience initializer for a snapshot-driven gate with no fallback.
    init(
        _ feature: F,
        snapshot: FeatureFlagSnapshot,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(feature, snapshot: snapshot, content: content, fallback: { EmptyView() })
    }

    /// Convenience initializer for a service-driven gate with no fallback.
    init(
        _ feature: F,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(feature, content: content, fallback: { EmptyView() })
    }
}
