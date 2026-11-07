import Foundation
import TGFeatureFlagCore

/// Handles an edit made in the debug screen.
///
/// `value == nil` clears the override. The key is the flag's `lookupKey` — the same key space
/// `DebugProvider.setOverride` writes and the snapshot uses — so a Redux app can forward the
/// call into a store action without unwrapping a key enum first.
public typealias FeatureFlagOverrideHandler = (_ key: String, _ value: FeatureFlagValue?) -> Void

/// What one debug row displays, separated from the SwiftUI view so the display rules are
/// testable without rendering anything.
struct FeatureFlagDebugEditorModel: Equatable {

    /// The editor family a row renders, decided by the key's declared default value.
    enum Kind: Equatable {
        case bool
        case string
        case int
        case double
    }

    let kind: Kind
    /// The value the row edits: whatever resolved, or the default when nothing did.
    ///
    /// Normalised for the editor — an integer read as a `Double` is presented as that double,
    /// so the double field seeds from `1.0` instead of falling back to `0`.
    let currentValue: FeatureFlagValue
    /// What the source actually returned, before normalisation. Kept so a notice can quote it.
    let storedValue: FeatureFlagValue
    let defaultValue: FeatureFlagValue
    let isOverridden: Bool
    /// A source returned a case the key does not declare — a stale remote value or a
    /// hand-written override. The row still edits the declared type; the mismatch is shown
    /// rather than silently swallowed, because a hidden mismatch looks exactly like a flag
    /// that is simply switched off.
    let hasTypeMismatch: Bool
    /// An integer read as a `Double`. Resolves normally rather than falling back, so this is a
    /// notice about the payload's shape, not an error.
    let isWidened: Bool

    init(defaultValue: FeatureFlagValue, resolved: FeatureFlagValue?, isOverridden: Bool) {
        let kind = Self.kind(of: defaultValue)
        let resolvedKind = resolved.map(Self.kind(of:))
        let stored = resolved ?? defaultValue
        let widened = kind == .double && resolvedKind == .int

        self.kind = kind
        self.defaultValue = defaultValue
        self.storedValue = stored
        self.currentValue = widened ? Self.widened(stored) : stored
        self.isOverridden = isOverridden
        self.isWidened = widened
        self.hasTypeMismatch = resolvedKind.map { $0 != kind && !widened } ?? false
    }

    static func kind(of value: FeatureFlagValue) -> Kind {
        switch value {
        case .bool: return .bool
        case .string: return .string
        case .int: return .int
        case .double: return .double
        }
    }

    /// Widens an integer into the double it stands for.
    ///
    /// `Double(Int)` is exact for every value in `Int`'s range up to 2^53 and rounds beyond
    /// it, which matches what `JSONDecoder` already did when it handed the integer over.
    private static func widened(_ value: FeatureFlagValue) -> FeatureFlagValue {
        guard case .int(let value) = value else { return value }
        return .double(Double(value))
    }

    /// The value to write when the row is reset to the flag's default.
    var resetValue: FeatureFlagValue { defaultValue }

    /// The resolved value for a mismatch notice, quoted so an empty string stays visible.
    var currentValueDescription: String { Self.literal(storedValue) }

    /// What the row reads at a glance.
    var displayText: String {
        guard !hasTypeMismatch else {
            return "\(Self.literal(currentValue)) (expected \(Self.label(for: kind)))"
        }

        switch currentValue {
        case .bool(let value): return value ? "ON" : "OFF"
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(format: "%.2f", value)
        }
    }

    static func label(for kind: Kind) -> String {
        switch kind {
        case .bool: return "bool"
        case .string: return "string"
        case .int: return "int"
        case .double: return "double"
        }
    }

    private static func literal(_ value: FeatureFlagValue) -> String {
        switch value {
        case .bool(let value): return value ? "true" : "false"
        case .string(let value): return "\"\(value)\""
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        }
    }
}

/// Chooses the value a debug row shows.
///
/// An explicit snapshot wins over the environment service — the same precedence `FeatureGate`
/// uses, for the same reason: in a Store-driven app, showing the service's values would
/// display decisions the app is not actually running with.
@MainActor
enum FeatureFlagDebugResolution {

    static func value<F: FeatureFlagKey>(
        for feature: F,
        snapshot: FeatureFlagSnapshot?,
        service: FeatureFlagService?
    ) -> FeatureFlagValue? {
        if let snapshot {
            // No fallthrough to the service: a snapshot that lacks the key means the app has
            // no value for it, and the row should say so rather than invent one.
            return snapshot.rawValue(for: feature)
        }
        return service?.rawValue(for: feature)
    }

    /// Whether the row should wear the "overridden" marker.
    ///
    /// A snapshot is a resolved result and cannot say where a value came from, so snapshot
    /// mode relies on the set the app supplies. Both sources are honoured so passing a
    /// snapshot in an app that also has a `DebugProvider` still shows the marker.
    static func isOverridden<F: FeatureFlagKey>(
        for feature: F,
        overriddenKeys: Set<String>,
        debugProvider: DebugProvider?
    ) -> Bool {
        overriddenKeys.contains(feature.lookupKey)
            || debugProvider?.value(for: feature.lookupKey) != nil
    }
}
