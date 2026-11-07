import Foundation

/// Shared percentage-rollout decision, used by both the code-configured and the
/// remotely-configured rollout providers.
///
/// Extracted so the two providers cannot drift on the three cases that matter: 100% is always
/// on, 0% is always off (and must *not* fall through to a lower provider), and anything in
/// between is decided by a stable bucket.
enum RolloutResolution {
    /// Resolves the value for one rollout entry.
    ///
    /// - Parameters:
    ///   - userId: Identity used for bucketing.
    ///   - key: Lookup key; also the bucket salt, so different flags split differently.
    ///   - percentage: Requested rollout percentage; clamped to 0...100.
    ///   - customValue: Value returned when the user is inside the rollout.
    static func value(
        userId: String,
        key: String,
        percentage: Int,
        customValue: FeatureFlagValue?
    ) -> FeatureFlagValue {
        let clamped = max(0, min(100, percentage))

        // 100%: always inside. 0%: always outside, and deliberately does not fall through.
        if clamped >= 100 { return customValue ?? .bool(true) }
        if clamped <= 0 { return customValue ?? .bool(false) }

        return isInRollout(userId: userId, key: key, percentage: clamped)
            ? (customValue ?? .bool(true))
            : .bool(false)
    }

    static func isInRollout(userId: String, key: String, percentage: Int) -> Bool {
        let bucket = Int(StableHash.fnv1a64("\(userId):\(key)") % 100)
        return bucket < percentage
    }
}
