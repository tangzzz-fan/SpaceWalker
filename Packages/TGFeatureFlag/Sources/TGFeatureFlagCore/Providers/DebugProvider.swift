import Foundation
import os

/// A mutable provider intended for debug builds.
/// Allows runtime toggling of feature flags to test different states.
public final class DebugProvider: FeatureFlagChangePublishing, Sendable {
    public let name: String = "Debug Override"

    private let lock = OSAllocatedUnfairLock(initialState: [String: FeatureFlagValue]())
    private let changes = FeatureFlagChangeBroadcaster()

    public init() {}

    public func value(for key: String) -> FeatureFlagValue? {
        lock.withLock { overrides in
            overrides[key]
        }
    }

    /// Overrides a feature flag value.
    /// Uses `feature.lookupKey` so grouped flags match service/resolver lookups.
    public func setOverride<F: FeatureFlagKey>(for feature: F, value: FeatureFlagValue?) {
        let key = feature.lookupKey
        lock.withLock { overrides in
            if let value {
                overrides[key] = value
            } else {
                overrides.removeValue(forKey: key)
            }
        }
        changes.notify()
    }

    /// Clears all overrides.
    public func reset() {
        let hadOverrides = lock.withLock { overrides -> Bool in
            let had = !overrides.isEmpty
            overrides.removeAll()
            return had
        }
        // Skip the notification when there was nothing to clear, so a reset on an untouched
        // provider does not invalidate every observer for no reason.
        if hadOverrides { changes.notify() }
    }

    public func observeChanges(_ handler: @escaping @Sendable () -> Void) -> FeatureFlagChangeObservation {
        changes.observe(handler)
    }
}
