import Foundation

/// Protocol defining a source for Feature Flag values.
///
/// Providers can be chained in `FeatureFlagResolver` or `FeatureFlagService`. Common examples:
/// - `DebugProvider`: Overrides from a developer menu.
/// - `RemoteConfigProvider`: Values fetched from a backend.
/// - `LocalProvider`: Default values hardcoded or from a local file.
public protocol FeatureFlagProvider: Sendable {
    /// The unique name of the provider (e.g., "RemoteConfig", "Debug").
    var name: String { get }

    /// Retrieves the value for a specific feature flag.
    /// - Parameter key: The feature flag lookup key string (`FeatureFlagKey.lookupKey`).
    /// - Returns: The value if found, otherwise `nil`.
    func value(for key: String) -> FeatureFlagValue?
}

/// Defines where a provider is inserted in the resolution chain.
///
/// - `highest`: Inserted at the front (priority = Int.max).
/// - `lowest`: Inserted at the end (priority = Int.min).
/// - `custom(Int)`: Inserted at a specific priority level. Higher values = higher priority.
public enum FeatureFlagPriority: Sendable, Equatable {
    case highest
    case lowest
    case custom(Int)

    public var rawValue: Int {
        switch self {
        case .highest: return Int.max
        case .lowest: return Int.min
        case .custom(let value): return value
        }
    }
}
