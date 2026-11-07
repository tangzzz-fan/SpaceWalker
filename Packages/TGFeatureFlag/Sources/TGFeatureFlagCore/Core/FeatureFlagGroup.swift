import Foundation

/// Protocol for organizing feature flags into logical groups with a shared key prefix.
///
/// Use this to namespace your feature flags in large applications, preventing key collisions
/// and improving organization.
///
/// Example:
/// ```swift
/// enum UIFeature: String, FeatureFlagKey {
///     case newDesign
///     case darkMode
///
///     var defaultValue: FeatureFlagValue { .bool(true) }
///
///     static var group: FeatureFlagGroup {
///         FeatureFlagGroup(prefix: "ui")
///     }
/// }
///
/// // The actual key used in providers will be "ui.newDesign", "ui.darkMode"
/// ```
public struct FeatureFlagGroup: Sendable, Hashable {
    /// The prefix applied to all keys in this group.
    public let prefix: String
    
    /// The separator between the prefix and the key. Defaults to ".".
    public let separator: String
    
    /// Creates a feature flag group.
    /// - Parameters:
    ///   - prefix: The namespace prefix.
    ///   - separator: The separator between prefix and key. Defaults to ".".
    public init(prefix: String, separator: String = ".") {
        self.prefix = prefix
        self.separator = separator
    }
    
    /// Returns the fully qualified key for a given raw value.
    public func qualifiedKey(for rawValue: String) -> String {
        "\(prefix)\(separator)\(rawValue)"
    }
}

/// Protocol that feature flag enums can adopt to participate in a group.
///
/// When a `FeatureFlagKey` conforms to `GroupedFeatureFlag`, the service will
/// use the group's qualified key for provider lookups.
///
/// Example:
/// ```swift
/// enum CheckoutFeature: String, FeatureFlagKey, GroupedFeatureFlag {
///     case v2Flow
///     case newPayment
///
///     var defaultValue: FeatureFlagValue { .bool(false) }
///
///     static var group: FeatureFlagGroup {
///         FeatureFlagGroup(prefix: "checkout")
///     }
/// }
/// ```
public protocol GroupedFeatureFlag: FeatureFlagKey {
    /// The group this feature flag belongs to.
    static var group: FeatureFlagGroup { get }
}

public extension FeatureFlagKey where Self: GroupedFeatureFlag {
    /// Returns the fully qualified key including the group prefix.
    var qualifiedKey: String {
        Self.group.qualifiedKey(for: rawValue)
    }
}
