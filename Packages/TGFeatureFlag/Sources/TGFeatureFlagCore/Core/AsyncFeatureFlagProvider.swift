import Foundation

/// Protocol for feature flag providers that fetch values asynchronously (e.g., remote config services).
///
/// Async providers cache values locally after a fetch. The synchronous `value(for:)` method
/// returns cached values, while `fetchValues()` performs the actual async fetch operation.
///
/// Use `FeatureFlagResolver.refresh()` or `FeatureFlagService.refresh()` to trigger a fetch
/// across all registered async providers.
///
/// Example:
/// ```swift
/// final class FirebaseProvider: AsyncFeatureFlagProvider, @unchecked Sendable {
///     let name = "Firebase"
///     private let lock = OSAllocatedUnfairLock(initialState: [String: FeatureFlagValue]())
///
///     func value(for key: String) -> FeatureFlagValue? {
///         lock.withLock { $0[key] }
///     }
///
///     func fetchValues() async throws {
///         let config = try await RemoteConfig.remoteConfig().fetchAndActivate()
///         // Map remote values into FeatureFlagValue and store under lock.
///     }
/// }
/// ```
public protocol AsyncFeatureFlagProvider: FeatureFlagProvider {
    /// Fetches the latest values from the remote source.
    ///
    /// Implementations should update their internal cache so that subsequent
    /// calls to `value(for:)` return the new values.
    func fetchValues() async throws
}
