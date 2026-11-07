import Foundation

/// A cold, Sendable snapshot of resolved feature-flag values.
///
/// Intended for Redux-style apps: resolve once (via `FeatureFlagResolver`), dispatch the
/// snapshot into the Store, and treat the Store as the source of truth. This type is a
/// **generic** key → value map; app domains map it into business-shaped DTOs.
///
/// The snapshot is immutable by construction. That is what makes it safe to treat as a
/// value: an in-place edit would let a "cold" snapshot drift after it was dispatched,
/// defeating both equality-based dispatch de-duplication and any audit of what the app
/// actually resolved at a point in time.
public struct FeatureFlagSnapshot: Sendable, Equatable, Codable, Hashable {
    /// Resolved values keyed by lookup key (`FeatureFlagKey.lookupKey`).
    public let values: [String: FeatureFlagValue]

    public init(values: [String: FeatureFlagValue] = [:]) {
        self.values = values
    }

    public subscript(key: String) -> FeatureFlagValue? {
        values[key]
    }

    /// Returns the stored value for a typed feature key, if present.
    ///
    /// Untyped escape hatch; prefer `value(for:)` when the key type is known.
    public func rawValue<F: FeatureFlagKey>(for feature: F) -> FeatureFlagValue? {
        values[feature.lookupKey]
    }

    /// Returns the resolved value in the key's declared type, falling back to the key's typed
    /// default when the snapshot has no entry or holds a different case.
    public func value<F: TypedFeatureFlag>(for feature: F) -> F.Value {
        guard let stored = values[feature.lookupKey],
              let typed = F.Value(featureFlagValue: stored) else {
            return feature.typedDefaultValue
        }
        return typed
    }

    /// Whether a boolean flag is enabled.
    ///
    /// Only compiles for keys whose value type is `Bool`.
    public func isEnabled<F: TypedFeatureFlag>(_ feature: F) -> Bool where F.Value == Bool {
        value(for: feature)
    }

    public func bool(for key: String) -> Bool? {
        values[key]?.boolValue
    }

    public func string(for key: String) -> String? {
        values[key]?.stringValue
    }

    public func int(for key: String) -> Int? {
        values[key]?.intValue
    }

    public func double(for key: String) -> Double? {
        values[key]?.doubleValue
    }
}
