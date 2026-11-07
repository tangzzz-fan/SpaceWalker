# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.1] - 2026-11-03

### Fixed
- **Type-mismatch and widening events are deduplicated.** Both are read-path events, so a misconfigured flag read inside a SwiftUI body reported on every render: one bad remote value produced 381 `typeMismatch` events in five seconds in the example app. They are now deduplicated per flag, expected type and offending value, on the same session boundary as exposures. A *different* offending value is a different problem and still reports, so no signal is lost — only the repetition. This also makes `.standard` safe to leave on in production, which is what its option set already claimed: it excludes `.resolutions` precisely because per-read events are too noisy, yet shipped two other per-read events by default.

## [1.1.0] - 2026-11-02

### Added
- **`Double` flags accept an integer payload.** `JSONDecoder` erases the decimal point, so a backend writing `{"value": 1}` for a ratio produced `.int(1)`, which failed the typed read and silently ran the flag on its shipped default — indistinguishable from a flag that was switched off. The read now widens the integer, and reports a new `valueWidened` event so the shape of the payload is still visible. Widening is one-directional and `Double`-only: an `Int` flag still rejects `1.5` (truncating it would be a lossy read), and `1` is still not `true`.
- **Bare-literal decoding is pinned by tests**, including the two places where a hand-written payload does not survive the round trip: `1.0` and `1e3` decode as integers (`JSONDecoder` erases the decimal point), and integers beyond `Int.max` fall back to a double. The first of those is now handled by the `Double` widening above; the second still rounds, so keep integral configuration values inside `Int` range.
- **CI gates**: the workflow builds with `-warnings-as-errors`, runs tests with coverage, prints the per-file table and fails below a 65% line-coverage floor.

### Changed
- **`FeatureFlagEvent` gained `valueWidened`.** A `switch` over every case needs a branch for it (or a `default`) when you rebuild against 1.1. It shares the `.typeMismatches` option, so a sink that already reports type mismatches sees it without any configuration.

## [1.0.0] - 2026-11-02

### Added
- **`FeatureFlagDebugView` works in both modes.** Pass `snapshot:` with `onOverride:` to use it in Redux / Store-as-SoT apps — the explicit snapshot wins over the environment service, the same precedence `FeatureGate` applies, and edits reach the app as `(lookupKey, value)` calls (`nil` clears an override) instead of assuming a `DebugProvider`. The service-driven `init()` is unchanged. With neither source the screen explains the mistake instead of trapping. Row display rules live in a testable model; rows show a visible warning when a stored value's type does not match the key's declared type, and every editor gained a per-flag reset button.
- **`TypedFeatureFlag`**: keys carry their value type, so `value(for:)` returns `Bool` / `String` / `Int` / `Double` directly and `isEnabled` only compiles for `Bool` keys. Reading a string flag as a boolean is now a compile error instead of a silent fallback. `rawValue(for:)` remains as the untyped escape hatch for tooling.
- **`RemoteRolloutProvider`** and **`RolloutConfiguration`**: rollout percentages come from a backend document, so moving a rollout from 5% to 50% no longer needs a release. The document accepts bare JSON literals; malformed entries are skipped and reported in `ignoredKeys` instead of failing the whole payload.
- **`FeatureFlagEvent`** / **`FeatureFlagEventSink`** / `FeatureFlagEventOptions`: typed events for resolution, exposure, type mismatch and refresh outcomes, replacing `FeatureFlagLogger`. Exposure events are deduplicated per flag and value, with `startNewSession()` to begin a new reporting session.
- **`LastKnownGoodStore`** and **`CachedSnapshotProvider`**: persist the last successfully refreshed snapshot and prime the provider chain from disk at launch, so a cold start renders the values the app actually had last session instead of shipped defaults. `load()` never throws — a missing or corrupt file returns `nil` and the app falls back to defaults.
- **`FeatureFlagChangePublishing`**, **`FeatureFlagChangeBroadcaster`** and `FeatureFlagChangeObservation`: a fan-out change-notification mechanism providers can adopt. Fan-out rather than `AsyncStream`, which is single-consumer and would make two resolvers compete for elements.
- **`FeatureFlagRefreshReport`**: per-provider refresh outcome and duration.
- **`TGFeatureFlagCore` / `TGFeatureFlagSwiftUI` products.** `TGFeatureFlagCore` contains no SwiftUI, so "the core does not depend on the UI" is now a compile-time fact rather than a documentation rule. `TGFeatureFlag` remains as an umbrella that re-exports both, so existing `import TGFeatureFlag` call sites keep compiling.

### Fixed
- **Observer leak in `FeatureFlagService`**: the `UserDefaults` observer was registered with the block-based API but removed with `removeObserver(self)`, which only removes selector-based registrations. The closure therefore outlived every service instance for the lifetime of the process. The registration token is now owned by a helper that unregisters on `deinit`.
- **Tautological hash test**: the "Fixed FNV-1a vector" assertion compared the hash against itself, so any change to the hash would still have passed. Replaced with pinned constants.

### Changed
- **`FeatureFlagService` is now a shell over `FeatureFlagResolver`.** It no longer keeps a second copy of the provider list or a parallel implementation of `register` / `setLogger` / `refresh` / `provider(ofType:)`, so the two modes can no longer drift apart and "one source of truth" is a structural property instead of a documentation rule.
- **Providers publish their own changes.** `FeatureFlagChangePublishing` + `FeatureFlagChangeBroadcaster` let `DebugProvider` and `RolloutProvider` invalidate observers when their values change, so the UI no longer depends on callers remembering to call `triggerUpdate()`.
- **`RolloutProvider.userId` is settable** and notifies on change. Identity is no longer frozen at construction, so signing in or switching accounts re-buckets instead of silently keeping the previous user's assignment.
- **One `FeatureGate` for both modes** — it takes either `snapshot:` or the environment service. `SnapshotFeatureGate` is gone. An explicit snapshot wins over the environment service, because preferring the service would reintroduce the second source of truth.
- **`FeatureGate` degrades instead of trapping** when neither a snapshot nor a service is present: it falls back to the flag default and reports the mistake via `assertionFailure` in debug builds.
- **`refresh()` runs providers concurrently** and applies a per-provider timeout, so one slow source no longer delays or blocks the others.
- **`refresh()` returns `FeatureFlagRefreshReport`** (per-provider result and duration) instead of a failure count, so callers can tell "network down" apart from "credentials expired".
- **`FeatureFlagSnapshot.values` is read-only** — a dispatched snapshot can no longer be mutated underneath the Store.
- **Snapshot JSON is explicit and tagged** (`{"type":"bool","value":true}`) instead of the compiler-synthesised `{"bool":{"_0":true}}`. Integral doubles such as `.double(1.0)` now round-trip as doubles rather than collapsing to integers.
- **`FeatureFlagService(observeUserDefaults:)`** — observing `UserDefaults` is opt-in and off by default, because the notification is process-wide and short-lived instances should not register observers.
- **Docs**: documented the priority tie-break rule, the pinned rollout hash vectors, and the snapshot wire format.

### Breaking
- `value(for:)` now returns the key's declared type and requires `TypedFeatureFlag`; use `rawValue(for:)` for the old untyped behaviour.
- `isEnabled` requires `F.Value == Bool`; `boolValue` / `stringValue` / `intValue` / `doubleValue` were removed in favour of typed `value(for:)`.
- `FeatureFlagKey`'s `defaultValue` should be replaced by `typedDefaultValue` when adopting `TypedFeatureFlag`; the untyped default is derived automatically.
- Mixed-type key enums must be split, because `TypedFeatureFlag.Value` is a single associated type.
- `FeatureFlagLogger` was replaced by `FeatureFlagEventSink`; refresh outcomes are now typed events rather than `flag: "*"` with the error text inside the value field.
- `refresh()` now `throws` and returns `FeatureFlagRefreshReport`; read `.failures` from the report. `CancellationError` propagates, provider failures do not.
- `SnapshotFeatureGate` was removed; use `FeatureGate(_:snapshot:)` instead.
- Snapshots persisted in the previous `{"bool":{"_0":true}}` shape will no longer decode.
- `FeatureFlagService()` no longer observes `UserDefaults`; pass `observeUserDefaults: true` to keep the old behaviour.
- `RolloutProvider.userId` is no longer a `let`; code that relied on it being fixed now observes identity changes.

## [0.5.0] - 2026-08-25

### Added
- **`FeatureFlagValue`**: Typed `bool` / `string` / `int` / `double` values (`Sendable`, `Equatable`, `Codable`). Replaces `Any` on keys, providers, and loggers.
- **`FeatureFlagSnapshot`**: Cold key → value map for Redux / Store-as-SoT apps.
- **`FeatureFlagResolver`**: Non-MainActor `Sendable` resolver with `value` / `isEnabled` / `snapshot(for:)` / `refresh()`. Aligns with TGReduxKit 5.0.1 `FeatureFlagFetching` adapter shape (no Redux dependency).
- **`SnapshotFeatureGate`**: SwiftUI gate driven by an injected snapshot (no `FeatureFlagService` environment).
- **`FeatureFlagPriority`**: Shared priority enum for Resolver and Service.
- **Stable rollout hashing**: FNV-1a 64-bit over UTF-8 (`userId:key`).
- **Tests**: Grouped + debug override, 0% blocks fallthrough, stable hash, Resolver snapshot / Codable.

### Changed
- **`swiftLanguageModes: [.v6]`** in `Package.swift`.
- **`FeatureFlagKey.defaultValue`**: now `FeatureFlagValue`.
- **`FeatureFlagProvider.value(for:)`**: returns `FeatureFlagValue?`.
- **Unified `lookupKey`**: Debug / Rollout / Local(`enabledFeatures`) write the same key Service/Resolver read (fixes grouped override miss).
- **`FeatureFlagService`**: returns `FeatureFlagValue`; adds `boolValue` / `stringValue` / `intValue` / `doubleValue` / `snapshot(for:)`. Documented as non-Redux / demo SoT only.
- **Docs**: README + DesignInfo describe dual mode and Redux Store-as-SoT; install version `from: "0.5.0"`.

### Fixed
- **0% rollout** now returns `.bool(false)` instead of `nil` (no accidental fallthrough).
- Removed fake `try/catch` around non-throwing provider lookups.
- Removed resolution-path `fatalError` on type mismatch.

### Breaking
- Call sites must migrate `defaultValue` and provider dictionaries from `Any` / untyped literals to `FeatureFlagValue`.
- `service.value(for:)` no longer returns a generic `T`; use typed accessors or switch on `FeatureFlagValue`.
- `FeatureFlagLogger.log(..., value:)` now takes `FeatureFlagValue?`.
- `DebugProvider.setOverride` / `RolloutProvider.setRollout` take `FeatureFlagValue` (and use `lookupKey`).

## [0.4.0] - 2026-07-04

### Added
- **tvOS and watchOS Support**: Added `.tvOS(.v17)` and `.watchOS(.v10)` platform targets.
- **RolloutProvider**: New provider enabling percentage-based feature flag rollouts. Uses deterministic hashing of a user identifier to ensure consistent results per user. Supports custom rollout values and per-flag configuration.
- **FeatureFlagGroup & GroupedFeatureFlag Protocol**: Namespace support for organizing feature flags into logical groups. Grouped flags automatically use qualified keys (e.g., `"ui.newDesign"`) for provider lookups.
- **Grouped Flag Tests**: Added 9 new tests covering rollout percentages (0%, 50%, 100%), deterministic hashing, custom rollout values, qualified keys, custom separators, and fallback behavior.

### Changed
- **FeatureFlagService Key Resolution**: `value(for:)` now resolves qualified keys for flags conforming to `GroupedFeatureFlag`, enabling seamless group-based provider lookups.

## [0.3.0] - 2026-07-04

### Added
- **AsyncFeatureFlagProvider Protocol**: New protocol for providers that fetch values asynchronously (e.g., Firebase Remote Config, LaunchDarkly). Async providers cache values locally and expose them via the synchronous `value(for:)` method.
- **FeatureFlagService.refresh()**: Async method that triggers `fetchValues()` on all registered `AsyncFeatureFlagProvider` instances. Returns the number of providers that failed to refresh. Automatically triggers UI update after refresh.
- **Async Provider Tests**: Added 3 new tests for async refresh, failure handling, and mixed sync/async provider chains.

### Changed
- **Demo App**: `MockRemoteProvider` now implements `AsyncFeatureFlagProvider`. Settings view uses `await service.refresh()` instead of callback-based API.

## [0.2.0] - 2026-07-04

### Added
- **Numeric Priority System**: `Priority.custom(Int)` allows fine-grained provider ordering. Higher values = higher priority. Providers are automatically sorted by priority level.
- **FeatureFlagLogger Protocol**: New `FeatureFlagLogger` protocol enables observing which provider resolved each flag, useful for production debugging. Use `service.setLogger(_:)` to install.
- **Provider Fault Tolerance**: Provider value lookups are now guarded; a failing provider will be skipped and the next provider in the chain will be tried.
- **Expanded Test Coverage**: Added 8 new tests covering custom priority, mixed priority levels, empty provider chain, `DebugProvider.reset()`, `provider(ofType:)` lookup, logger resolution, and `LocalProvider(enabledFeatures:)` initializer.

### Changed
- **Internal Provider Storage**: Providers are now stored as sorted entries with their priority level, enabling correct insertion order for custom priorities.

## [0.1.0] - 2026-07-04

### Added
- **Int/Double Editors in Debug View**: `FeatureFlagDebugView` now supports editing `Int` values via `Stepper` and `Double` values via numeric `TextField`.
- **Swift 6 Concurrency Safety**: Added `@MainActor` annotation to `FeatureFlagService` for safe use with Swift 6 strict concurrency.

### Changed
- **FeatureGate Lazy Construction**: `FeatureGate` now stores `@ViewBuilder` closures instead of eagerly evaluated views, ensuring only the active branch is constructed.
- **UserDefaultsProvider Documentation**: Added thread-safety note explaining why `@unchecked Sendable` is appropriate.

### Fixed
- Removed unused `Combine` import in `UserDefaultsProvider.swift`.
- Fixed `FeatureGate` eager view construction that could cause unnecessary view instantiation.

## [0.0.1] - 2026-01-18

### Added
- **Non-Boolean Value Support**: Feature flags now support `String`, `Int`, `Double`, and other types in addition to `Bool`.
- **Generic Value Retrieval**: Added `value(for:)` method to `FeatureFlagService` for type-safe value access.
- **Demo App Enhancements**:
  - Added "Checkout V2" flow demonstration with visual feedback.
  - Added "Product Detail" page showing conditional navigation and layout adaptation.
  - Added "API Base URL" configuration example.
- **Documentation**: Added English `README.md` and updated Chinese architecture design document.

### Changed
- **Architecture**: Refactored `FeatureFlagKey` and `FeatureFlagProvider` protocols to support `Any` type values.
- **Testing**: Migrated test suite from XCTest to Swift Testing framework.
- **Thread Safety**: Improved thread safety in `LocalProvider` and `MockRemoteProvider` using `Sendable` conformance.
- **Debug View**: Updated `FeatureFlagDebugView` to support editing String values.

### Fixed
- Fixed generic parameter inference issues in SwiftUI views.
- Fixed layout occlusion issues in Product Detail page when navigation bar is hidden.

[1.1.1]: https://github.com/tangzzz-fan/TGFeatureFlag/compare/1.1.0...1.1.1
[1.1.0]: https://github.com/tangzzz-fan/TGFeatureFlag/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/tangzzz-fan/TGFeatureFlag/releases/tag/1.0.0
[0.5.0]: https://github.com/tangzzz-fan/TGFeatureFlag/compare/0.0.1...0.5.0
[0.0.1]: https://github.com/tangzzz-fan/TGFeatureFlag/releases/tag/0.0.1
