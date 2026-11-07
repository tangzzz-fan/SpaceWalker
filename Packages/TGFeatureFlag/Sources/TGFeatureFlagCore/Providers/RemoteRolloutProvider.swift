import Foundation
import os

/// A rollout document, as delivered by a backend.
///
/// ```json
/// {
///   "rollouts": {
///     "checkout.v2_flow": { "percentage": 25 },
///     "config_banner_text": { "percentage": 50, "value": "Try the new checkout" }
///   }
/// }
/// ```
///
/// `value` is optional and accepts either a bare literal (`true`, `3`, `"text"`, `1.5`) or the
/// tagged form the library writes itself. Bare literals are the point: a backend authoring
/// `{"type":"bool","value":true}` by hand for every flag would be miserable.
///
/// Malformed entries are skipped rather than failing the whole document, because one bad key
/// should not take every other rollout down with it. Skipped keys are reported in
/// `ignoredKeys` so the app can log them.
public struct RolloutConfiguration: Sendable, Equatable {

    /// One flag's rollout.
    public struct Entry: Sendable, Equatable {
        /// Requested percentage, clamped to 0...100.
        public var percentage: Int
        /// Value returned to users inside the rollout. Defaults to `true` when absent.
        public var value: FeatureFlagValue?

        public init(percentage: Int, value: FeatureFlagValue? = nil) {
            self.percentage = max(0, min(100, percentage))
            self.value = value
        }
    }

    public var rollouts: [String: Entry]

    /// Keys that were present in the payload but could not be parsed.
    public let ignoredKeys: [String]

    public init(rollouts: [String: Entry] = [:]) {
        self.rollouts = rollouts
        self.ignoredKeys = []
    }

    public subscript(key: String) -> Entry? {
        rollouts[key]
    }
}

extension RolloutConfiguration: Codable {
    private enum CodingKeys: String, CodingKey {
        case rollouts
    }

    /// Decodes one entry, or `nil` when it is malformed.
    private struct LenientEntry: Decodable {
        let entry: Entry?

        init(from decoder: any Decoder) throws {
            entry = try? Entry(from: decoder)
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decodeIfPresent([String: LenientEntry].self, forKey: .rollouts) ?? [:]

        var parsed: [String: Entry] = [:]
        var ignored: [String] = []
        for (key, lenient) in raw {
            if let entry = lenient.entry {
                parsed[key] = entry
            } else {
                ignored.append(key)
            }
        }

        self.rollouts = parsed
        // Sorted so the value is stable: dictionary iteration order is not.
        self.ignoredKeys = ignored.sorted()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rollouts, forKey: .rollouts)
    }
}

extension RolloutConfiguration.Entry: Codable {
    private enum CodingKeys: String, CodingKey {
        case percentage
        case value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let percentage = try container.decode(Int.self, forKey: .percentage)

        // A present-but-unparseable value makes the whole entry malformed: defaulting it to
        // `true` would enable a flag the backend meant to configure precisely.
        var decoded: FeatureFlagValue?
        if container.contains(.value) {
            decoded = try container.decode(FeatureFlagValue.self, forKey: .value)
        }

        self.init(percentage: percentage, value: decoded)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(percentage, forKey: .percentage)
        try container.encodeIfPresent(value, forKey: .value)
    }
}

/// A rollout provider whose percentages come from a remote document.
///
/// `RolloutProvider` can only be configured in code, so moving a rollout from 5% to 50% used to
/// require a release — which defeats the point of decoupling deploy from release. This provider
/// takes the same decisions from a payload instead, and republishes changes so the UI updates
/// as soon as a new document is applied.
public final class RemoteRolloutProvider: FeatureFlagChangePublishing, Sendable {
    public let name: String

    private let lock: OSAllocatedUnfairLock<State>
    private let changes = FeatureFlagChangeBroadcaster()

    private struct State: Sendable {
        var userId: String
        var rollouts: [String: RolloutConfiguration.Entry] = [:]
        var ignoredKeys: [String] = []
    }

    public init(userId: String, name: String = "Remote Rollout") {
        self.name = name
        self.lock = OSAllocatedUnfairLock(initialState: State(userId: userId))
    }

    /// Identity used for bucketing. Settable so signing in or switching accounts re-buckets.
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

    /// Keys from the most recently applied payload that could not be parsed.
    public var ignoredKeys: [String] {
        lock.withLock { $0.ignoredKeys }
    }

    /// Replaces the entire rollout set with the payload's contents.
    ///
    /// Replacement rather than merge: a remote config document describes the current truth, so
    /// a flag that disappeared from the payload must stop rolling out instead of silently
    /// keeping its last percentage.
    public func apply(_ configuration: RolloutConfiguration) {
        lock.withLock { state in
            state.rollouts = configuration.rollouts
            state.ignoredKeys = configuration.ignoredKeys
        }
        changes.notify()
    }

    /// Decodes and applies a JSON payload.
    ///
    /// - Throws: only when the payload is not a JSON object with the expected top-level shape.
    ///   Individual malformed entries are skipped and reported in `ignoredKeys`.
    public func apply(json data: Data) throws {
        apply(try JSONDecoder().decode(RolloutConfiguration.self, from: data))
    }

    /// Removes every rollout, so flags fall through to lower providers.
    public func clear() {
        let hadRollouts = lock.withLock { state -> Bool in
            let had = !state.rollouts.isEmpty
            state.rollouts.removeAll()
            state.ignoredKeys = []
            return had
        }
        if hadRollouts { changes.notify() }
    }

    public func value(for key: String) -> FeatureFlagValue? {
        let (userId, entry): (String, RolloutConfiguration.Entry?) = lock.withLock { state in
            (state.userId, state.rollouts[key])
        }

        guard let entry else { return nil }

        return RolloutResolution.value(
            userId: userId,
            key: key,
            percentage: entry.percentage,
            customValue: entry.value
        )
    }

    public func observeChanges(_ handler: @escaping @Sendable () -> Void) -> FeatureFlagChangeObservation {
        changes.observe(handler)
    }
}
