import Foundation
import os

/// A provider that can announce that its values changed.
///
/// Without this, a provider mutating its cache is invisible: the UI keeps rendering whatever
/// it resolved last, because nothing told Observation to re-read. That is why a rollout
/// percentage changed at runtime, or an override set from debug tooling, used to require a
/// manual `triggerUpdate()` call.
///
/// Adopt this on any provider whose values can change after registration. `LocalProvider`
/// does not need it: its values are immutable.
public protocol FeatureFlagChangePublishing: FeatureFlagProvider {
    /// Registers a handler invoked after this provider's values change.
    ///
    /// The handler may be called from any thread. Release the returned observation to stop
    /// listening.
    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> FeatureFlagChangeObservation
}

/// A live subscription to a provider's change notifications.
///
/// Releasing the token unsubscribes. The owning provider keeps the handler alive, so a token
/// that is dropped stops the handler from being called.
public final class FeatureFlagChangeObservation: Sendable {
    private let onCancel: @Sendable () -> Void

    public init(onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    deinit {
        onCancel()
    }
}

/// A reusable fan-out hub for providers that publish changes.
///
/// Providers keep one instance and call `notify()` after mutating state; custom providers can
/// use the same helper instead of reimplementing handler bookkeeping.
///
/// Fan-out rather than `AsyncStream` on purpose: an `AsyncStream` is single-consumer, so two
/// resolvers observing the same provider would compete for elements instead of both seeing
/// every change.
public final class FeatureFlagChangeBroadcaster: Sendable {
    private let handlers = OSAllocatedUnfairLock(initialState: [UUID: @Sendable () -> Void]())

    public init() {}

    public func observe(_ handler: @escaping @Sendable () -> Void) -> FeatureFlagChangeObservation {
        let id = UUID()
        handlers.withLock { $0[id] = handler }

        return FeatureFlagChangeObservation { [weak self] in
            guard let self else { return }
            _ = handlers.withLock { $0.removeValue(forKey: id) }
        }
    }

    /// Calls every current handler. Handlers are copied first so that subscribing or
    /// unsubscribing from inside a handler cannot deadlock or mutate the iteration.
    public func notify() {
        let snapshot = handlers.withLock { Array($0.values) }
        for handler in snapshot {
            handler()
        }
    }
}
