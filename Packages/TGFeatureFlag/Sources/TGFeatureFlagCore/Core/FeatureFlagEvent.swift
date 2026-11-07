import Foundation
import os

/// Something worth reporting about feature-flag resolution.
///
/// The previous interface was `log(flag:resolvedBy:value:)`, which had nowhere to put a refresh
/// failure, so refresh outcomes were smuggled through as `flag: "*"` with the error text inside
/// the `value` field. That made the data unusable: you could not tell an event about a flag from
/// an event about a provider, and the error lived in a field typed as a flag value.
public enum FeatureFlagEvent: Sendable, Equatable {
    /// A flag was resolved. Fires on every read, so it is off by default.
    case resolved(flag: String, provider: String?, value: FeatureFlagValue)

    /// A flag was shown to this session for the first time with this value.
    ///
    /// Deduplicated per flag and value, which is what makes the stream usable for A/B analysis:
    /// a view that reads a flag on every frame must not look like thousands of users.
    case exposure(flag: String, value: FeatureFlagValue)

    /// A provider returned a value whose case does not match the key's declared type.
    case typeMismatch(flag: String, expected: String, actual: FeatureFlagValue)

    /// A provider returned an integer where the key declares `Double`. The value is used,
    /// widened — this is a notice, not a failure.
    ///
    /// Reported separately from `typeMismatch` because the two have opposite outcomes: a
    /// mismatch falls back to the default, a widening resolves. Folding the widening into
    /// `typeMismatch` would make every double flag read as misconfigured the moment a backend
    /// writes `{"value": 1}`.
    case valueWidened(flag: String, expected: String, actual: FeatureFlagValue)

    /// A provider refreshed successfully.
    case refreshed(provider: String, duration: Duration)

    /// A provider threw while refreshing.
    case refreshFailed(provider: String, reason: String)

    /// A provider did not finish within the refresh timeout.
    case refreshTimedOut(provider: String)
}

/// Receives feature-flag events.
///
/// Called synchronously on whichever thread resolved the flag, so implementations must be fast
/// and must not call back into the resolver. Buffer or forward to another queue rather than doing
/// I/O here.
public protocol FeatureFlagEventSink: Sendable {
    func receive(_ event: FeatureFlagEvent)
}

/// Which events to emit.
///
/// `.resolutions` is excluded from `standard` on purpose: it fires on every read, which is fine
/// for a debug session and wasteful in production.
public struct FeatureFlagEventOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// One event per flag and value per session.
    public static let exposures = FeatureFlagEventOptions(rawValue: 1 << 0)

    /// Every resolution. Verbose; intended for debugging.
    public static let resolutions = FeatureFlagEventOptions(rawValue: 1 << 1)

    /// Provider refresh outcomes.
    public static let refresh = FeatureFlagEventOptions(rawValue: 1 << 2)

    /// A provider returned a value whose case does not match the key's declared type.
    ///
    /// Includes the values it accepted anyway by widening an integer to a `Double`.
    ///
    /// Both are read-path events, so both are deduplicated per flag, expected type and
    /// offending value — see `typeMismatch(flag:expected:actual:)`.
    public static let typeMismatches = FeatureFlagEventOptions(rawValue: 1 << 3)

    /// Exposures, refresh outcomes and type mismatches.
    public static let standard: FeatureFlagEventOptions = [.exposures, .refresh, .typeMismatches]

    /// Everything, including a per-read resolution event.
    public static let all: FeatureFlagEventOptions = [.exposures, .resolutions, .refresh, .typeMismatches]
}

/// Remembers which values have already been reported in this session.
///
/// Used for both exposures and type mismatches. Both are read-path events, so without
/// deduplication a flag read inside a SwiftUI body reports once per frame — thousands of
/// times a session — and the data is useless for analysis.
final class FeatureFlagOnceLog<Key: Hashable & Sendable>: Sendable {
    private let seen = OSAllocatedUnfairLock(initialState: Set<Key>())

    /// - Returns: `true` the first time a key is seen.
    func record(_ key: Key) -> Bool {
        seen.withLock { $0.insert(key).inserted }
    }

    func reset() {
        seen.withLock { $0.removeAll() }
    }
}

/// Fan-out point for events, passed down to the resolution helpers.
///
/// Optional everywhere so that a resolver with no sink pays nothing: no allocation, no branch on
/// the hot path beyond a single nil check.
struct FeatureFlagEventEmitter: Sendable {
    private struct ExposureKey: Hashable, Sendable {
        let flag: String
        let value: FeatureFlagValue
    }

    private struct MismatchKey: Hashable, Sendable {
        let flag: String
        let expected: String
        let actual: FeatureFlagValue
    }

    let sink: any FeatureFlagEventSink
    let options: FeatureFlagEventOptions

    private let exposures = FeatureFlagOnceLog<ExposureKey>()
    private let mismatches = FeatureFlagOnceLog<MismatchKey>()

    func resolved(flag: String, provider: String?, value: FeatureFlagValue) {
        guard options.contains(.resolutions) else { return }
        sink.receive(.resolved(flag: flag, provider: provider, value: value))
    }

    func exposure(flag: String, value: FeatureFlagValue) {
        guard options.contains(.exposures) else { return }
        guard exposures.record(ExposureKey(flag: flag, value: value)) else { return }
        sink.receive(.exposure(flag: flag, value: value))
    }

    /// Reports a value whose case does not match the key's declared type.
    ///
    /// Deduplicated per flag, expected type and actual value: a misconfigured flag stays
    /// misconfigured for the whole session, so re-reporting it on every read would drown the
    /// sink without adding information. A change in the offending value does report again.
    func typeMismatch(flag: String, expected: String, actual: FeatureFlagValue) {
        guard options.contains(.typeMismatches) else { return }
        let key = MismatchKey(flag: flag, expected: expected, actual: actual)
        guard mismatches.record(key) else { return }
        sink.receive(.typeMismatch(flag: flag, expected: expected, actual: actual))
    }

    /// Reports a value that was accepted by widening, e.g. an integer payload read as a
    /// `Double`.
    ///
    /// Shares the mismatch log: for a given flag and value a resolution either widens or
    /// mismatches, never both, so one dedupe set covers both events.
    func valueWidened(flag: String, expected: String, actual: FeatureFlagValue) {
        guard options.contains(.typeMismatches) else { return }
        let key = MismatchKey(flag: flag, expected: expected, actual: actual)
        guard mismatches.record(key) else { return }
        sink.receive(.valueWidened(flag: flag, expected: expected, actual: actual))
    }

    func refreshed(provider: String, duration: Duration) {
        guard options.contains(.refresh) else { return }
        sink.receive(.refreshed(provider: provider, duration: duration))
    }

    func refreshFailed(provider: String, reason: String) {
        guard options.contains(.refresh) else { return }
        sink.receive(.refreshFailed(provider: provider, reason: reason))
    }

    func refreshTimedOut(provider: String) {
        guard options.contains(.refresh) else { return }
        sink.receive(.refreshTimedOut(provider: provider))
    }

    func startNewSession() {
        exposures.reset()
        mismatches.reset()
    }
}
