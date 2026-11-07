import Foundation

/// Shared resolution helpers used by `FeatureFlagResolver` and `FeatureFlagService`.
enum FeatureFlagResolution {
    struct ProviderEntry: Sendable {
        let priority: Int
        let provider: any FeatureFlagProvider
    }

    static func insert(
        _ entry: ProviderEntry,
        into entries: inout [ProviderEntry]
    ) {
        if let index = entries.firstIndex(where: { entry.priority > $0.priority }) {
            entries.insert(entry, at: index)
        } else {
            entries.append(entry)
        }
    }

    static func resolveValue(
        forKey lookupKey: String,
        defaultValue: FeatureFlagValue,
        providers: [ProviderEntry],
        events: FeatureFlagEventEmitter?
    ) -> FeatureFlagValue {
        for entry in providers {
            if let value = entry.provider.value(for: lookupKey) {
                events?.resolved(flag: lookupKey, provider: entry.provider.name, value: value)
                events?.exposure(flag: lookupKey, value: value)
                return value
            }
        }

        events?.resolved(flag: lookupKey, provider: nil, value: defaultValue)
        // A default is still a variant the user was exposed to, so it counts for analysis.
        events?.exposure(flag: lookupKey, value: defaultValue)
        return defaultValue
    }

    static func resolveValue<F: FeatureFlagKey>(
        for feature: F,
        providers: [ProviderEntry],
        events: FeatureFlagEventEmitter?
    ) -> FeatureFlagValue {
        resolveValue(
            forKey: feature.lookupKey,
            defaultValue: feature.defaultValue,
            providers: providers,
            events: events
        )
    }

    /// Resolves a typed flag, unwrapping the stored value into the key's declared type.
    ///
    /// A provider can return a different case than the key declares — a stale remote value, or
    /// a misconfigured override. Falling back to the typed default keeps the call site
    /// non-optional rather than forcing every read to handle a shape the key says is impossible.
    /// The mismatch itself is reported, because a silent fallback here looks exactly like a flag
    /// that is simply switched off.
    ///
    /// One case is accepted rather than rejected: an integer read as a `Double`. The wire
    /// format cannot tell `1` from `1.0`, so that payload is compatible, not broken — but it
    /// still reports `valueWidened`, because a whole-number double is usually a backend that
    /// meant `1` for a percentage rather than a double that happens to be integral.
    static func resolveTypedValue<F: TypedFeatureFlag>(
        for feature: F,
        providers: [ProviderEntry],
        events: FeatureFlagEventEmitter?
    ) -> F.Value {
        let raw = resolveValue(for: feature, providers: providers, events: events)
        let expected = String(describing: F.Value.self)

        guard let typed = F.Value(featureFlagValue: raw) else {
            events?.typeMismatch(
                flag: feature.lookupKey,
                expected: expected,
                actual: raw
            )
            return feature.typedDefaultValue
        }

        if F.Value.wideningDescription(of: raw) != nil {
            events?.valueWidened(flag: feature.lookupKey, expected: expected, actual: raw)
        }

        return typed
    }

    static func snapshot<S: Sequence>(
        for features: S,
        providers: [ProviderEntry],
        events: FeatureFlagEventEmitter?
    ) -> FeatureFlagSnapshot where S.Element: FeatureFlagKey {
        var values: [String: FeatureFlagValue] = [:]
        for feature in features {
            let key = feature.lookupKey
            values[key] = resolveValue(
                forKey: key,
                defaultValue: feature.defaultValue,
                providers: providers,
                events: events
            )
        }
        return FeatureFlagSnapshot(values: values)
    }

    /// Raised internally when a provider outlives the refresh timeout.
    struct RefreshTimeout: Error {}

    /// Refreshes every async provider concurrently.
    ///
    /// Concurrent rather than sequential because provider latency would otherwise add up:
    /// three providers at 100 ms each cost 300 ms sequentially. A single slow provider must
    /// not delay the others either, so each one gets its own timeout.
    ///
    /// - Throws: `CancellationError` if the calling task is cancelled. Provider failures are
    ///   reported in the result instead of being thrown, so one broken source cannot prevent
    ///   the remaining ones from refreshing.
    static func refresh(
        providers: [ProviderEntry],
        events: FeatureFlagEventEmitter?,
        timeout: Duration
    ) async throws -> FeatureFlagRefreshReport {
        let candidates = providers.compactMap { entry -> (name: String, provider: any AsyncFeatureFlagProvider)? in
            guard let asyncProvider = entry.provider as? any AsyncFeatureFlagProvider else {
                return nil
            }
            return (entry.provider.name, asyncProvider)
        }

        guard !candidates.isEmpty else { return FeatureFlagRefreshReport() }

        let collected = try await withThrowingTaskGroup(
            of: (Int, FeatureFlagRefreshReport.Outcome).self,
            returning: [(Int, FeatureFlagRefreshReport.Outcome)].self
        ) { group in
            for (index, candidate) in candidates.enumerated() {
                group.addTask {
                    let outcome = try await refreshOne(
                        candidate.provider,
                        name: candidate.name,
                        timeout: timeout,
                        events: events
                    )
                    return (index, outcome)
                }
            }

            var results: [(Int, FeatureFlagRefreshReport.Outcome)] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        // Restore registration order so the report is deterministic regardless of completion order.
        return FeatureFlagRefreshReport(outcomes: collected.sorted { $0.0 < $1.0 }.map(\.1))
    }

    private static func refreshOne(
        _ provider: any AsyncFeatureFlagProvider,
        name: String,
        timeout: Duration,
        events: FeatureFlagEventEmitter?
    ) async throws -> FeatureFlagRefreshReport.Outcome {
        let clock = ContinuousClock()
        let started = clock.now

        do {
            try await withTimeout(timeout) { try await provider.fetchValues() }
            events?.refreshed(provider: name, duration: clock.now - started)
            return .init(providerName: name, result: .refreshed, duration: clock.now - started)
        } catch is RefreshTimeout {
            events?.refreshTimedOut(provider: name)
            return .init(providerName: name, result: .timedOut, duration: clock.now - started)
        } catch is CancellationError {
            // Cancellation belongs to the caller, not to this provider: let it propagate.
            throw CancellationError()
        } catch {
            events?.refreshFailed(provider: name, reason: String(describing: error))
            return .init(
                providerName: name,
                result: .failed(String(describing: error)),
                duration: clock.now - started
            )
        }
    }

    /// Runs `operation`, abandoning it once `timeout` elapses.
    private static func withTimeout<T: Sendable>(
        _ timeout: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw RefreshTimeout()
            }

            defer { group.cancelAll() }

            guard let result = try await group.next() else { throw RefreshTimeout() }
            return result
        }
    }
}
