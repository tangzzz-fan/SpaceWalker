import Foundation

/// Owns a block-based `NotificationCenter` registration and unregisters it on deinit.
///
/// `NotificationCenter.removeObserver(_:)` only removes *selector-based* registrations.
/// A registration made with the block-based API must be removed with the token returned
/// at registration time, so that token is owned here and released together with this object.
///
/// This keeps the cleanup out of the owning type's `deinit`, which matters for `@MainActor`
/// types under Swift 6: a nonisolated `deinit` cannot touch a non-`Sendable` token, but it can
/// let a `Sendable`-free helper release it for it.
final class NotificationObservation {
    private var token: NSObjectProtocol?

    init(
        name: Notification.Name,
        object: Any? = nil,
        queue: OperationQueue? = nil,
        handler: @Sendable @escaping () -> Void
    ) {
        token = NotificationCenter.default.addObserver(
            forName: name,
            object: object,
            queue: queue
        ) { _ in
            handler()
        }
    }

    deinit {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
