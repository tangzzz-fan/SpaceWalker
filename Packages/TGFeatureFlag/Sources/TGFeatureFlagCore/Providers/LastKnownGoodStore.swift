import Foundation

/// Persists the last successfully refreshed snapshot so the next cold start renders real
/// values instead of defaults.
///
/// Without this, every launch starts from `defaultValue` and then jumps to the remote values
/// once a refresh lands. Users see the interface switch styles under them — the most common
/// visible defect in flag-driven UI, and the reason a flag that is "on for everyone" can still
/// look broken for the first second of every session.
///
/// Typical wiring:
/// ```swift
/// let store = LastKnownGoodStore(namespace: "app")
///
/// // Launch: prime the chain from disk before any network call.
/// if let cached = store.load() {
///     resolver.register(
///         provider: CachedSnapshotProvider(snapshot: cached),
///         priority: .custom(10)   // below remote, above local defaults
///     )
/// }
///
/// // After a successful refresh: remember what the app actually resolved.
/// try? store.save(resolver.snapshot(for: AppFeature.allCases))
/// ```
///
/// Reading never throws. A missing, truncated, or unrecognised file yields `nil` so the app
/// falls back to defaults rather than failing to launch.
public struct LastKnownGoodStore: Sendable {
    /// Groups cache files, so several apps or test suites can share a directory.
    public let namespace: String

    private let directory: URL

    /// - Parameters:
    ///   - namespace: File name prefix; use one per app or feature area.
    ///   - directory: Where to store the file. Defaults to `Application Support/TGFeatureFlag`.
    public init(namespace: String, directory: URL? = nil) {
        self.namespace = namespace
        self.directory = directory ?? Self.defaultDirectory
    }

    /// `Application Support/TGFeatureFlag`, created lazily on first save.
    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appending(path: "TGFeatureFlag", directoryHint: .isDirectory)
    }

    /// The file backing this store.
    public var fileURL: URL {
        directory.appending(path: "\(namespace)-last-known-good.json", directoryHint: .notDirectory)
    }

    /// Writes the snapshot atomically, so an interrupted write cannot leave a half file that
    /// would be read as a corrupt cache on the next launch.
    public func save(_ snapshot: FeatureFlagSnapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Reads the cached snapshot, or `nil` when it is absent or unreadable.
    public func load() -> FeatureFlagSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(FeatureFlagSnapshot.self, from: data)
    }

    /// Removes the cached snapshot. Safe to call when nothing is cached.
    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

/// Serves values from a snapshot loaded off disk.
///
/// Register it below the remote provider and above local defaults: cached values are better
/// than shipped defaults but worse than anything fetched this session.
public struct CachedSnapshotProvider: FeatureFlagProvider {
    public let name: String
    private let snapshot: FeatureFlagSnapshot

    public init(snapshot: FeatureFlagSnapshot, name: String = "Last Known Good") {
        self.snapshot = snapshot
        self.name = name
    }

    public func value(for key: String) -> FeatureFlagValue? {
        snapshot[key]
    }
}
