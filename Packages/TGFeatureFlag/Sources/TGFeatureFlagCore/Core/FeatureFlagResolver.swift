import Foundation
import os

/// A Sendable, non-MainActor resolver that materializes feature-flag values and snapshots.
///
/// Prefer this path for Redux / TGReduxKit-style apps: refresh providers, build a
/// `FeatureFlagSnapshot`, map it in an app adapter, then `dispatch(.loaded(...))`.
/// The Store remains the source of truth — do not also hang `@Observable FeatureFlagService`
/// in the environment as a second SoT.
///
/// Example adapter shape (app-owned, not in this package):
/// ```swift
/// struct TGFFFetchingAdapter: FeatureFlagFetching {
///     let resolver: FeatureFlagResolver
///     func fetchSnapshot() async -> AppFeatureFlagSnapshot {
///         _ = await resolver.refresh()
///         let remote = resolver.snapshot(for: AppFeature.allCases)
///         return AppFeatureFlagSnapshot(/* map keys → domain fields */)
///     }
/// }
/// ```
public final class FeatureFlagResolver: Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: State())

    private struct State {
        var providerEntries: [FeatureFlagResolution.ProviderEntry] = []
        var events: FeatureFlagEventEmitter?
        var changeObservations: [FeatureFlagChangeObservation] = []
        var changeHandler: (@Sendable () -> Void)?
    }

    public typealias Priority = FeatureFlagPriority

    public init() {}

    /// Registers a new provider with a given priority.
    ///
    /// Providers that publish their own changes are subscribed automatically, so a value
    /// mutated after registration reaches the change handler without the caller doing
    /// anything.
    public func register(provider: any FeatureFlagProvider, priority: Priority = .lowest) {
        lock.withLock { state in
            let entry = FeatureFlagResolution.ProviderEntry(
                priority: priority.rawValue,
                provider: provider
            )
            FeatureFlagResolution.insert(entry, into: &state.providerEntries)

            if let publishing = provider as? any FeatureFlagChangePublishing {
                let observation = publishing.observeChanges { [weak self] in
                    self?.publishChange()
                }
                state.changeObservations.append(observation)
            }
        }
    }

    /// Called whenever any registered provider reports a change.
    ///
    /// Set by `FeatureFlagService` to invalidate SwiftUI observers. Redux apps normally do not
    /// need it: the Store is updated by whatever fetched the snapshot.
    public func setChangeHandler(_ handler: (@Sendable () -> Void)?) {
        lock.withLock { state in
            state.changeHandler = handler
        }
    }

    /// Invokes the change handler outside the lock, so a handler that re-enters the resolver
    /// cannot deadlock.
    private func publishChange() {
        let handler = lock.withLock { $0.changeHandler }
        handler?()
    }

    /// Installs an event sink.
    ///
    /// - Parameter options: Which events to emit. `.resolutions` is excluded from `.standard`
    ///   because it fires on every read; enable it only when debugging.
    public func setEventSink(
        _ sink: (any FeatureFlagEventSink)?,
        options: FeatureFlagEventOptions = .standard
    ) {
        lock.withLock { state in
            state.events = sink.map { FeatureFlagEventEmitter(sink: $0, options: options) }
        }
    }

    /// Starts a new exposure session, so each flag and value is reported again.
    ///
    /// Call this when a session boundary means something for analysis — a new app session, or a
    /// change of user identity.
    public func startNewSession() {
        lock.withLock { $0.events?.startNewSession() }
    }

    /// Resolves a flag into the value type its key declares.
    public func value<F: TypedFeatureFlag>(for feature: F) -> F.Value {
        let (entries, events) = lock.withLock { state in
            (state.providerEntries, state.events)
        }
        return FeatureFlagResolution.resolveTypedValue(
            for: feature,
            providers: entries,
            events: events
        )
    }

    /// Resolves a flag without unwrapping it.
    ///
    /// The untyped escape hatch: used by debug tooling and by callers that only have
    /// `any FeatureFlagKey`. Prefer `value(for:)` when the key type is known.
    public func rawValue<F: FeatureFlagKey>(for feature: F) -> FeatureFlagValue {
        let (entries, events) = lock.withLock { state in
            (state.providerEntries, state.events)
        }
        return FeatureFlagResolution.resolveValue(
            for: feature,
            providers: entries,
            events: events
        )
    }

    /// Checks if a feature is enabled.
    ///
    /// Only compiles for keys whose value type is `Bool`, so asking a string flag whether it is
    /// "enabled" is a compile error rather than a silent fallback.
    public func isEnabled<F: TypedFeatureFlag>(_ feature: F) -> Bool where F.Value == Bool {
        value(for: feature)
    }

    /// Builds a cold snapshot for the given keys.
    public func snapshot<S: Sequence>(
        for features: S
    ) -> FeatureFlagSnapshot where S.Element: FeatureFlagKey {
        let (entries, events) = lock.withLock { state in
            (state.providerEntries, state.events)
        }
        return FeatureFlagResolution.snapshot(
            for: features,
            providers: entries,
            events: events
        )
    }

    /// Refreshes all registered `AsyncFeatureFlagProvider` instances concurrently.
    ///
    /// - Parameter timeout: Per-provider limit. A provider that exceeds it is reported as
    ///   `.timedOut` and the remaining providers still refresh.
    /// - Returns: A per-provider report.
    /// - Throws: `CancellationError` when the calling task is cancelled.
    @discardableResult
    public func refresh(timeout: Duration = .seconds(10)) async throws -> FeatureFlagRefreshReport {
        let (entries, events) = lock.withLock { state in
            (state.providerEntries, state.events)
        }
        return try await FeatureFlagResolution.refresh(
            providers: entries,
            events: events,
            timeout: timeout
        )
    }

    /// Helper to find a specific provider type.
    public func provider<T>(ofType type: T.Type) -> T? {
        let providers = lock.withLock { state in
            state.providerEntries.map(\FeatureFlagResolution.ProviderEntry.provider)
        }
        return providers.first { $0 is T } as? T
    }
}
