import Foundation

/// Protocol defining the unique identifier and default behavior for a Feature Flag.
///
/// Implement this protocol (usually on an Enum) to define the available flags in your application.
///
/// Example:
/// ```swift
/// enum AppFeature: String, FeatureFlagKey {
///     case newProfile
///     case apiBaseUrl
///
///     var defaultValue: FeatureFlagValue {
///         switch self {
///         case .newProfile: return .bool(true)
///         case .apiBaseUrl: return .string("https://api.example.com")
///         }
///     }
/// }
/// ```
public protocol FeatureFlagKey: RawRepresentable, Sendable, Hashable where RawValue == String {
    /// The default value of the flag if no provider returns a specific value.
    var defaultValue: FeatureFlagValue { get }

    /// A human-readable description for debug tools (Optional).
    var description: String { get }
}

public extension FeatureFlagKey {
    var description: String { rawValue }

    /// The key used for provider lookups.
    ///
    /// Grouped flags use `qualifiedKey`; otherwise `rawValue`.
    var lookupKey: String {
        if let grouped = self as? any GroupedFeatureFlag {
            return grouped.qualifiedKey
        }
        return rawValue
    }
}
