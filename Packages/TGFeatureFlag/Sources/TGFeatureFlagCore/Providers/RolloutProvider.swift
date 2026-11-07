import Foundation
import os

/// A provider that enables percentage-based feature flag rollouts.
///
/// Uses a deterministic FNV-1a hash of a user identifier to decide whether a feature
/// is enabled for a given user. This ensures the same user consistently gets
/// the same result for a given rollout percentage across process launches.
///
/// Example:
/// ```swift
/// let rollout = RolloutProvider(userId: "user-123")
/// rollout.setRollout(for: "new_feature", percentage: 50) // 50% rollout
/// resolver.register(provider: rollout, priority: .custom(80))
/// ```
public final class RolloutProvider: FeatureFlagChangePublishing, Sendable {
    public let name: String

    private let lock: OSAllocatedUnfairLock<State>
    private let changes = FeatureFlagChangeBroadcaster()

    private struct State: Sendable {
        /// The identity used for bucketing.
        var userId: String
        /// Per-flag rollout percentages (0-100).
        var rollouts: [String: Int] = [:]
        /// Per-flag overrides for specific flag values (non-Bool).
        var rolloutValues: [String: FeatureFlagValue] = [:]
    }

    /// Initializes with a user identifier for deterministic hashing.
    /// - Parameters:
    ///   - userId: A stable identifier for the current user (e.g., user ID, device UUID).
    ///   - name: A display name for this provider.
    public init(userId: String, name: String = "Rollout") {
        self.name = name
        lock = OSAllocatedUnfairLock(initialState: State(userId: userId))
    }

    /// The identity used for bucketing.
    ///
    /// Settable because identity changes at runtime — a user signs in, signs out, or switches
    /// accounts. Buckets are derived from this value, so a stale identity silently keeps
    /// serving the previous user's assignment. Assigning notifies observers so the UI
    /// re-resolves against the new buckets.
    public var userId: String {
        get { lock.withLock { $0.userId } }
        set {
            let changed = lock.withLock { state -> Bool in
                guard state.userId != newValue else { return false }
                state.userId = newValue
                return true
            }
            if changed { changes.notify() }
        }
    }

    /// Sets the rollout percentage for a feature flag.
    /// Uses `feature.lookupKey` so grouped flags match service/resolver lookups.
    /// - Parameters:
    ///   - feature: The feature flag key.
    ///   - percentage: The percentage of users (0-100) who should have this flag enabled.
    ///   - value: The value to return when the user is in the rollout (defaults to `.bool(true)`).
    public func setRollout<F: FeatureFlagKey>(
        for feature: F,
        percentage: Int,
        value: FeatureFlagValue? = nil
    ) {
        let key = feature.lookupKey
        lock.withLock { state in
            state.rollouts[key] = max(0, min(100, percentage))
            if let value {
                state.rolloutValues[key] = value
            } else {
                state.rolloutValues.removeValue(forKey: key)
            }
        }
        changes.notify()
    }

    /// Removes the rollout configuration for a feature flag.
    public func removeRollout<F: FeatureFlagKey>(for feature: F) {
        let key = feature.lookupKey
        let removed = lock.withLock { state -> Bool in
            let had = state.rollouts.removeValue(forKey: key) != nil
            state.rolloutValues.removeValue(forKey: key)
            return had
        }
        if removed { changes.notify() }
    }

    /// Returns the current rollout percentage for a flag, if set.
    public func rolloutPercentage(for key: String) -> Int? {
        lock.withLock { state in
            state.rollouts[key]
        }
    }

    public func value(for key: String) -> FeatureFlagValue? {
        let (userId, percentage, customValue): (String, Int?, FeatureFlagValue?) = lock.withLock { state in
            (state.userId, state.rollouts[key], state.rolloutValues[key])
        }

        guard let percentage else { return nil }

        return RolloutResolution.value(
            userId: userId,
            key: key,
            percentage: percentage,
            customValue: customValue
        )
    }

    public func observeChanges(_ handler: @escaping @Sendable () -> Void) -> FeatureFlagChangeObservation {
        changes.observe(handler)
    }
}

/// Stable, process-independent hashing for rollout bucketing.
enum StableHash {
    /// FNV-1a 64-bit over UTF-8 bytes.
    static func fnv1a64(_ string: String) -> UInt64 {
        let offsetBasis: UInt64 = 14695981039346656037
        let prime: UInt64 = 1099511628211
        var hash = offsetBasis
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }
}
