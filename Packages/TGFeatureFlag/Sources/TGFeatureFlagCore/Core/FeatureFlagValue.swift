import Foundation

/// A typed feature-flag value.
///
/// Replaces untyped `Any` storage so flag values are `Sendable`, `Equatable`, and `Codable`
/// and safe to put in Redux snapshots or cross actor boundaries.
///
/// The JSON form is deliberately explicit — `{"type": "bool", "value": true}` — rather than
/// the compiler-synthesised `{"bool": {"_0": true}}` or a bare `true`. A bare literal would be
/// ambiguous on the way back: `1` decodes as an integer, so `.double(1.0)` would silently
/// round-trip into `.int(1)`. The tag keeps the round trip lossless and lets a backend produce
/// the same shape by hand.
public enum FeatureFlagValue: Sendable, Equatable, Hashable {
    case bool(Bool)
    case string(String)
    case int(Int)
    case double(Double)

    /// The boolean payload, if this value is `.bool`.
    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    /// The string payload, if this value is `.string`.
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// The integer payload, if this value is `.int`.
    public var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    /// The double payload, if this value is `.double`.
    public var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }

    /// Creates a value from a `UserDefaults` / Objective-C bridge object when possible.
    public init?(any value: Any) {
        switch value {
        case let string as String:
            self = .string(string)
        case let number as NSNumber:
            // UserDefaults stores Bool/Int/Double as NSNumber — inspect objCType.
            let objCType = String(cString: number.objCType)
            if objCType == "c" || objCType == "B" {
                self = .bool(number.boolValue)
            } else if objCType == "d" || objCType == "f" {
                self = .double(number.doubleValue)
            } else {
                self = .int(number.intValue)
            }
        case let bool as Bool:
            self = .bool(bool)
        case let int as Int:
            self = .int(int)
        case let double as Double:
            self = .double(double)
        default:
            return nil
        }
    }
}

extension FeatureFlagValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bool(let value): return String(describing: value)
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        }
    }
}

extension FeatureFlagValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    /// The tag written to and read from JSON. Kept separate from the case names so that
    /// renaming a case cannot silently change the wire format.
    private var typeTag: String {
        switch self {
        case .bool: return "bool"
        case .string: return "string"
        case .int: return "int"
        case .double: return "double"
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(typeTag, forKey: .type)
        switch self {
        case .bool(let value): try container.encode(value, forKey: .value)
        case .string(let value): try container.encode(value, forKey: .value)
        case .int(let value): try container.encode(value, forKey: .value)
        case .double(let value): try container.encode(value, forKey: .value)
        }
    }

    public init(from decoder: any Decoder) throws {
        // Tagged form, as written by `encode(to:)` and by the snapshot wire format.
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           container.contains(.type) {
            let tag = try container.decode(String.self, forKey: .type)
            switch tag {
            case "bool": self = .bool(try container.decode(Bool.self, forKey: .value))
            case "string": self = .string(try container.decode(String.self, forKey: .value))
            case "int": self = .int(try container.decode(Int.self, forKey: .value))
            case "double": self = .double(try container.decode(Double.self, forKey: .value))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: """
                    Unknown feature flag value type "\(tag)". \
                    Expected one of: bool, string, int, double.
                    """
                )
            }
            return
        }

        // Bare literal form, for hand-authored remote payloads such as
        // `{"feature_x": {"percentage": 25, "value": true}}`. Requiring a backend to emit the
        // tagged shape for every value would make the payload painful to write by hand.
        // `JSONDecoder` is strict about `true` vs `1`, so the order below is unambiguous.
        let single = try decoder.singleValueContainer()
        if let bool = try? single.decode(Bool.self) { self = .bool(bool); return }
        if let int = try? single.decode(Int.self) { self = .int(int); return }
        if let double = try? single.decode(Double.self) { self = .double(double); return }
        if let string = try? single.decode(String.self) { self = .string(string); return }

        throw DecodingError.dataCorruptedError(
            in: single,
            debugDescription: """
            Expected a tagged flag value ({"type": ..., "value": ...}) \
            or a bare bool, number, or string.
            """
        )
    }
}
