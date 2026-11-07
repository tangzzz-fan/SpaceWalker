import Foundation

/// A Swift type that a feature flag can hold.
///
/// The set is deliberately closed to the four cases `FeatureFlagValue` supports: an open
/// protocol would let a conformer invent a value shape the snapshot wire format cannot encode.
public protocol FeatureFlagValueConvertible: Sendable, Equatable {
    /// Wraps the value for storage in a snapshot or provider.
    var featureFlagValue: FeatureFlagValue { get }

    /// Unwraps a stored value, or `nil` when the stored case does not match.
    init?(featureFlagValue: FeatureFlagValue)

    /// Names the stored case this type accepted without an exact match, or `nil` when the
    /// conversion was exact.
    ///
    /// Only `Double` widens, and only from `.int`. A JSON payload cannot distinguish `1` from
    /// `1.0` — `JSONDecoder` erases the decimal point — so refusing `.int` would make
    /// `{"value": 1}` fall back to the shipped default for a flag that is plainly a double.
    /// The widening is one-directional on purpose: `Int` does not accept `.double`, because
    /// truncating `1.5` to `1` would be a silent lossy read rather than a compatible one.
    static func wideningDescription(of value: FeatureFlagValue) -> String?
}

public extension FeatureFlagValueConvertible {
    /// Exact matches only, unless a conformer says otherwise.
    static func wideningDescription(of value: FeatureFlagValue) -> String? { nil }
}

extension Bool: FeatureFlagValueConvertible {
    public var featureFlagValue: FeatureFlagValue { .bool(self) }

    public init?(featureFlagValue: FeatureFlagValue) {
        guard case .bool(let value) = featureFlagValue else { return nil }
        self = value
    }
}

extension String: FeatureFlagValueConvertible {
    public var featureFlagValue: FeatureFlagValue { .string(self) }

    public init?(featureFlagValue: FeatureFlagValue) {
        guard case .string(let value) = featureFlagValue else { return nil }
        self = value
    }
}

extension Int: FeatureFlagValueConvertible {
    public var featureFlagValue: FeatureFlagValue { .int(self) }

    public init?(featureFlagValue: FeatureFlagValue) {
        guard case .int(let value) = featureFlagValue else { return nil }
        self = value
    }
}

extension Double: FeatureFlagValueConvertible {
    public var featureFlagValue: FeatureFlagValue { .double(self) }

    /// Accepts an integer as well, which the wire format forces: see
    /// `wideningDescription(of:)`.
    public init?(featureFlagValue: FeatureFlagValue) {
        switch featureFlagValue {
        case .double(let value): self = value
        case .int(let value): self = Double(value)
        default: return nil
        }
    }

    public static func wideningDescription(of value: FeatureFlagValue) -> String? {
        guard case .int = value else { return nil }
        return "Int"
    }
}

/// A feature flag whose value type is known to the compiler.
///
/// Adopting this makes a whole class of mistakes impossible at the call site: reading a boolean
/// flag yields a `Bool` rather than a `FeatureFlagValue` that callers must unwrap, and
/// `isEnabled` only accepts keys whose value type is `Bool`.
///
/// The cost is one value type per enum, because `Value` is an associated type. Mixed flags have
/// to live in separate enums — which is usually an improvement anyway, since a boolean switch
/// and a string configuration value have nothing in common beyond both being "flags".
///
/// ```swift
/// enum AppFeature: String, TypedFeatureFlag {
///     case newProfileDesign = "feature_new_profile"
///
///     var typedDefaultValue: Bool { false }
/// }
///
/// let enabled: Bool = resolver.isEnabled(AppFeature.newProfileDesign)
/// ```
public protocol TypedFeatureFlag: FeatureFlagKey {
    /// The Swift type this flag resolves to.
    associatedtype Value: FeatureFlagValueConvertible

    /// The value used when no provider supplies one.
    var typedDefaultValue: Value { get }
}

public extension TypedFeatureFlag {
    /// Derived from `typedDefaultValue`, so the two can never disagree.
    var defaultValue: FeatureFlagValue { typedDefaultValue.featureFlagValue }
}
