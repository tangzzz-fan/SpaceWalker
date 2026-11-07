import Foundation

/// What happened when the async providers were refreshed.
///
/// A bare failure count cannot distinguish "the network is down, keep serving cached values"
/// from "credentials expired, stop retrying" — two situations that need different responses.
/// The report keeps a per-provider outcome and timing so callers can tell them apart.
public struct FeatureFlagRefreshReport: Sendable, Equatable {

    /// The outcome of refreshing a single provider.
    public struct Outcome: Sendable, Equatable {
        public enum Result: Sendable, Equatable {
            /// The provider fetched successfully.
            case refreshed
            /// The provider did not finish within the refresh timeout.
            case timedOut
            /// The provider threw. The payload is a description for logging and display.
            case failed(String)
        }

        public let providerName: String
        public let result: Result
        public let duration: Duration

        public init(providerName: String, result: Result, duration: Duration) {
            self.providerName = providerName
            self.result = result
            self.duration = duration
        }

        public var didRefresh: Bool { result == .refreshed }
    }

    /// One outcome per async provider, in registration order.
    public let outcomes: [Outcome]

    public init(outcomes: [Outcome] = []) {
        self.outcomes = outcomes
    }

    /// The number of providers that did not refresh.
    public var failures: Int {
        outcomes.filter { !$0.didRefresh }.count
    }

    public var isSuccess: Bool { failures == 0 }

    /// Whether at least one provider succeeded, so the values in use are at least partly fresh.
    public var hasAnyFreshValue: Bool {
        outcomes.contains { $0.didRefresh }
    }
}
