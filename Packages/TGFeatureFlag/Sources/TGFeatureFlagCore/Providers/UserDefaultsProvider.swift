import Foundation

/// A provider that reads feature flags from UserDefaults.
/// This is commonly used to integrate with the iOS Settings.bundle or for simple persistence.
///
/// It observes `UserDefaults.didChangeNotification` to automatically notify the service of changes.
///
/// - Note: `UserDefaults` is documented as thread-safe by Apple, so `@unchecked Sendable` is appropriate here.
public final class UserDefaultsProvider: FeatureFlagProvider, @unchecked Sendable {
    public let name: String
    private let userDefaults: UserDefaults

    /// Initializes the provider.
    /// - Parameters:
    ///   - userDefaults: The UserDefaults instance to read from. Defaults to `.standard`.
    ///   - name: A display name for this provider. Defaults to "UserDefaults".
    public init(userDefaults: UserDefaults = .standard, name: String = "UserDefaults") {
        self.userDefaults = userDefaults
        self.name = name
    }

    public func value(for key: String) -> FeatureFlagValue? {
        guard let object = userDefaults.object(forKey: key) else {
            return nil
        }
        return FeatureFlagValue(any: object)
    }
}
