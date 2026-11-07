import Foundation

/// A simple provider backed by an in-memory dictionary.
/// Useful for setting up initial values or local configuration.
public struct LocalProvider: FeatureFlagProvider {
    public let name: String = "Local"
    private let flags: [String: FeatureFlagValue]

    /// Initializes with a dictionary of key-value pairs.
    public init(flags: [String: FeatureFlagValue]) {
        self.flags = flags
    }

    /// Initializes with a list of enabled keys (Sets them to true).
    /// Uses each feature's `lookupKey` so grouped flags match resolver lookups.
    public init(enabledFeatures: [any FeatureFlagKey]) {
        var dict: [String: FeatureFlagValue] = [:]
        for feature in enabledFeatures {
            dict[feature.lookupKey] = .bool(true)
        }
        self.flags = dict
    }

    public func value(for key: String) -> FeatureFlagValue? {
        flags[key]
    }
}
