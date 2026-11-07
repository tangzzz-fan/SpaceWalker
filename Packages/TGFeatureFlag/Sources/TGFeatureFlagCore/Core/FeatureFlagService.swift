import Foundation
import Observation

/// The SwiftUI-facing manager for feature flags in non-Redux / demo apps.
///
/// This is a thin `@Observable` shell over a `FeatureFlagResolver`. It owns no provider
/// storage and no resolution logic of its own: registering, logging, refreshing and provider
/// lookup all delegate. That matters because the previous version kept a second copy of the
/// provider list and a parallel implementation of the same four entry points, so the two
/// modes could drift apart — and "do not use this service alongside a Store snapshot as a
/// second source of truth" was a rule enforced only by documentation.
///
/// For Redux / TGReduxKit apps, prefer `FeatureFlagResolver` + `FeatureFlagSnapshot`
/// dispatched into the Store (the Store is the source of truth).
@MainActor
@Observable
public final class FeatureFlagService {

    /// The single engine. All resolution goes through here.
    private let resolver: FeatureFlagResolver

    /// Bumped whenever a source may have changed; read by every accessor.
    ///
    /// Observation tracks reads of stored properties, so a view that calls `value(for:)`
    /// depends on this property and is invalidated when it changes.
    ///
    /// A full `FeatureFlagSnapshot` would be the nicer signal, but the service resolves
    /// arbitrary `FeatureFlagKey` values on demand and holds no registry of every key, so
    /// there is no complete snapshot to store. Caching per key on first read would mean
    /// mutating observed state while a SwiftUI body is being evaluated, which SwiftUI
    /// explicitly warns against. A monotonic counter is the smallest honest mechanism.
    private var resolutionGeneration: Int = 0

    /// Kept alive for as long as the service lives; unregisters itself on deinit.
    private var userDefaultsObservation: NotificationObservation?

    public typealias Priority = FeatureFlagPriority

    /// Implementation-detail seam for tests: whether this instance currently holds a
    /// `UserDefaults` observation.
    var isObservingUserDefaults: Bool { userDefaultsObservation != nil }

    /// Creates the service.
    ///
    /// - Parameter observeUserDefaults: When `true`, any `UserDefaults` change re-resolves
    ///   flags so that `UserDefaultsProvider` values are reflected in the UI. This is opt-in
    ///   because the notification is process-wide: it fires for unrelated writes too, and
    ///   short-lived instances (tests, previews) would otherwise register observers that
    ///   outlive them.
    public init(observeUserDefaults: Bool = false) {
        resolver = FeatureFlagResolver()

        // A provider can change on any thread, so hop to the main actor before touching
        // observed state.
        resolver.setChangeHandler { [weak self] in
            Task { @MainActor in
                self?.triggerUpdate()
            }
        }

        guard observeUserDefaults else { return }

        userDefaultsObservation = NotificationObservation(
            name: UserDefaults.didChangeNotification,
            queue: .main
        ) { [weak self] in
            // `queue: .main` guarantees we are on the main thread, so this is safe and
            // avoids hopping through a new Task for every notification.
            MainActor.assumeIsolated {
                self?.triggerUpdate()
            }
        }
    }

    /// Registers a new provider with a given priority.
    public func register(provider: any FeatureFlagProvider, priority: Priority = .lowest) {
        resolver.register(provider: provider, priority: priority)
        triggerUpdate()
    }

    /// Installs an event sink.
    ///
    /// - Parameter options: Which events to emit. `.resolutions` is excluded from `.standard`
    ///   because it fires on every read.
    public func setEventSink(
        _ sink: (any FeatureFlagEventSink)?,
        options: FeatureFlagEventOptions = .standard
    ) {
        resolver.setEventSink(sink, options: options)
    }

    /// Starts a new exposure session, so each flag and value is reported again.
    public func startNewSession() {
        resolver.startNewSession()
    }

    /// Checks if a feature is enabled.
    ///
    /// Only compiles for keys whose value type is `Bool`.
    public func isEnabled<F: TypedFeatureFlag>(_ feature: F) -> Bool where F.Value == Bool {
        _ = resolutionGeneration
        return resolver.isEnabled(feature)
    }

    /// Resolves a flag into the value type its key declares.
    public func value<F: TypedFeatureFlag>(for feature: F) -> F.Value {
        // Reading the generation registers an Observation dependency for the caller.
        _ = resolutionGeneration
        return resolver.value(for: feature)
    }

    /// Resolves a flag without unwrapping it.
    ///
    /// The untyped escape hatch, for callers that only hold `any FeatureFlagKey`.
    public func rawValue<F: FeatureFlagKey>(for feature: F) -> FeatureFlagValue {
        _ = resolutionGeneration
        return resolver.rawValue(for: feature)
    }

    /// Builds a cold snapshot for the given keys (also useful from the Service path).
    public func snapshot<S: Sequence>(
        for features: S
    ) -> FeatureFlagSnapshot where S.Element: FeatureFlagKey {
        _ = resolutionGeneration
        return resolver.snapshot(for: features)
    }

    /// Manually invalidates every observer.
    ///
    /// Needed only for sources the service cannot observe itself, such as a provider mutated
    /// directly by debug tooling. Prefer changing the value through a provider that
    /// publishes its own changes.
    public func triggerUpdate() {
        resolutionGeneration += 1
    }

    /// Refreshes all registered `AsyncFeatureFlagProvider` instances concurrently.
    ///
    /// - Parameter timeout: Per-provider limit. A provider that exceeds it is reported as
    ///   `.timedOut` and the remaining providers still refresh.
    /// - Returns: A per-provider report.
    /// - Throws: `CancellationError` when the calling task is cancelled.
    @discardableResult
    public func refresh(timeout: Duration = .seconds(10)) async throws -> FeatureFlagRefreshReport {
        let report = try await resolver.refresh(timeout: timeout)
        triggerUpdate()
        return report
    }

    /// Helper to find a specific provider type.
    public func provider<T>(ofType type: T.Type) -> T? {
        resolver.provider(ofType: type)
    }
}
