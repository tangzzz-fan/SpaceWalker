# TGFeatureFlag

[![CI](https://github.com/tangzzz-fan/TGFeatureFlag/actions/workflows/ci.yml/badge.svg)](https://github.com/tangzzz-fan/TGFeatureFlag/actions/workflows/ci.yml)

A type-safe feature flag framework for Apple platforms, built with Swift 6 strict concurrency.

TGFeatureFlag decouples feature releases from code deployment, enabling safer releases, A/B testing, percentage-based rollouts, and dynamic configuration.

## Platforms

iOS 17+, macOS 14+, tvOS 17+, watchOS 10+

## Two modes

| Mode | When to use | Source of truth |
|------|-------------|-----------------|
| **Resolver + Snapshot** (recommended for Redux) | TGReduxKit / any Store-as-SoT app | App Store after `dispatch(.loaded(snapshot))` |
| **FeatureFlagService** (`@Observable`) | Demo / non-Redux SwiftUI apps | The service itself |

This package does **not** depend on TGReduxKit. Redux apps adapt `FeatureFlagResolver` to their own `FeatureFlagFetching`-style port (see [TGReduxKit 5.0.1 Shopping demo](https://github.com/tangzzz-fan/TGReduxKit) as the reference wiring).

```text
AsyncProvider.fetchValues → Resolver.refresh
Resolver.snapshot(for:) → App Adapter → dispatch(.loaded)
Reducer projects → Views read Store (not Environment Service)
```

## Example app

`Example/TGFeatureFlagDemo` is a runnable SwiftUI app that exercises the whole surface: typed keys, a seven-provider chain with explicit priorities, remote rollouts with an "ops console", cold start primed from the last-known-good cache, the per-provider refresh report, the event log with exposure deduplication, snapshot mode, and the debug override view.

```sh
cd Example/TGFeatureFlagDemo
xcodebuild -scheme TGFeatureFlagDemo -destination 'generic/platform=iOS Simulator' build
```

## Features

- **Typed values**: `FeatureFlagValue` (`bool` / `string` / `int` / `double`) — no `Any`, no resolution `fatalError`.
- **Typed keys**: `TypedFeatureFlag` makes reads return the declared Swift type, and `isEnabled` only accepts `Bool` keys.
- **Sendable Resolver**: build cold `FeatureFlagSnapshot` values for Redux middleware.
- **Priority chain**: `.highest` / `.lowest` / `.custom(Int)`.
- **Async providers**: `AsyncFeatureFlagProvider` + `refresh()`. Providers refresh concurrently, each with its own timeout, and the call returns a per-provider report.
- **Rollouts**: stable FNV-1a hashing (process-independent), configurable in code or from a remote payload.
- **Cold start**: `LastKnownGoodStore` persists the last good snapshot so launch renders real values instead of defaults.
- **Change notification**: providers publish their own changes, so the UI updates without manual triggers.
- **Observability**: typed events, with exposure events deduplicated per session.
- **Grouping**: `FeatureFlagGroup` / `GroupedFeatureFlag` with unified `lookupKey`.
- **SwiftUI**: one `FeatureGate` that takes either an injected snapshot or the environment service, and one `FeatureFlagDebugView` that works with either source too.
- **Debug screen in Redux**: pass the Store's snapshot and an override callback, so the Store stays the only writer.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/tangzzz-fan/TGFeatureFlag.git", from: "1.1.1")
]
```

The package ships three products:

| Product | Contents | Use when |
|---|---|---|
| `TGFeatureFlag` | Everything, re-exported | You just want `import TGFeatureFlag` |
| `TGFeatureFlagCore` | Resolution, providers, snapshots — no SwiftUI | Background agents, extensions, pure logic modules |
| `TGFeatureFlagSwiftUI` | Gates and the debug screen | You want the dependency to be explicit |

`TGFeatureFlagCore` has no SwiftUI dependency, so linking the core half does not pull view code into an app extension or a background target.

## Migrating from 0.5.0

1.0.0 is a breaking release: typed keys replace untyped reads, and the logger became a typed event sink. The mechanical part:

| 0.5.0 | 1.0.0 |
|---|---|
| `service.boolValue(for:)` / `stringValue` / `intValue` / `doubleValue` | `value(for:)`, on a key that adopts `TypedFeatureFlag` |
| `key.defaultValue` | `typedDefaultValue` (the untyped `defaultValue` is derived) |
| `FeatureFlagLogger` + `setLogger(_:)` | `FeatureFlagEventSink` + `setEventSink(_:options:)` |
| `refresh() -> Int` (failure count) | `try await refresh() -> FeatureFlagRefreshReport` |
| `SnapshotFeatureGate(_:snapshot:)` | `FeatureGate(_:snapshot:)` |
| `FeatureFlagService()` observes `UserDefaults` | `FeatureFlagService(observeUserDefaults: true)` |
| `RolloutProvider.userId` (constant) | settable; changing it re-buckets and notifies |
| Mutating `snapshot.values` | read-only; resolve a new snapshot instead |

Two things need a decision rather than a rename:

- **Split mixed-type key enums.** `TypedFeatureFlag.Value` is a single associated type, so a boolean switch and a string configuration value cannot share an enum. Split them — they have nothing in common beyond both being "flags".
- **Re-save cached snapshots.** Files written by 0.5.0 use the `{"bool":{"_0":true}}` shape and no longer decode. `LastKnownGoodStore.load()` returns `nil` for them, so the app falls back to defaults and rewrites the cache after the next successful refresh. Nothing crashes; the first launch after upgrading just loses the cold-start optimisation once.

`FeatureFlagService` no longer registers a `UserDefaults` observer unless asked, and `refresh()` now throws `CancellationError` when the caller is cancelled — provider failures still come back in the report rather than as throws.

## Migrating from 1.0.0

1.1.0 is additive apart from one enum case. `FeatureFlagEvent` gained `.valueWidened`, so an exhaustive `switch` over it needs a branch (or a `default`) when you rebuild. It shares the `.typeMismatches` option, so nothing has to be reconfigured to receive it.

Behaviour change worth knowing: a `Double` flag that receives an integer (`{"value": 1}`) now resolves to `1.0` instead of falling back to its shipped default. Anything that asserted on the old fallback — a test, or a dashboard counting `typeMismatch` events — will see the difference.

## Migrating from 1.1.0

1.1.1 changes no API. There is nothing to recompile for.

It does change how often two events are emitted. `typeMismatch` and `valueWidened` are read-path events — a flag read inside a `SwiftUI` body resolves on every render — and neither was deduplicated, so a single misconfigured flag could emit thousands of events per session. Both are now deduplicated per flag, expected type and offending value, on the same session boundary as exposures.

If you count those events, expect the count to drop to roughly one per distinct problem instead of one per read. That is the fix, not a regression: `.standard` is documented as safe to leave on in production, which it was not while a bad remote value could flood the sink. A *different* offending value still reports, so nothing is lost except the repetition. `startNewSession()` resets the dedupe, same as for exposures.

## Continuous Integration

GitHub Actions builds with `-warnings-as-errors` and runs `swift test --enable-code-coverage` for pushes and PRs targeting `main`. The job prints the per-file coverage table and fails below a 65% line-coverage floor, so a regression is caught in CI rather than in a release.

## Usage

### 1. Define Feature Flags

One value type per enum, because `TypedFeatureFlag.Value` is an associated type. Boolean switches and configuration values live in separate enums:

```swift
import TGFeatureFlag

enum AppFeature: String, TypedFeatureFlag, CaseIterable {
    case newProfileDesign = "feature_new_profile"
    case maxRetryCount = "config_retry_count"

    var typedDefaultValue: Bool {
        switch self {
        case .newProfileDesign: return false
        case .maxRetryCount: return true
        }
    }
}

enum AppConfig: String, TypedFeatureFlag, CaseIterable {
    case apiBaseUrl = "config_api_base_url"

    var typedDefaultValue: String { "https://api.production.com" }
}
```

Reads are typed, so there is nothing to unwrap:

```swift
let enabled: Bool = resolver.isEnabled(AppFeature.newProfileDesign)
let url: String = resolver.value(for: AppConfig.apiBaseUrl)
```

`isEnabled` only accepts keys whose value type is `Bool`, so asking a string flag whether it is "enabled" is a compile error rather than a silent fallback. `rawValue(for:)` is the untyped escape hatch for tooling.

### 2a. Redux path — Resolver + Snapshot

```swift
let resolver = FeatureFlagResolver()
resolver.register(provider: DebugProvider(), priority: .highest)
resolver.register(provider: MyRemoteProvider(), priority: .custom(80))
resolver.register(provider: LocalProvider(flags: [:]), priority: .lowest)

_ = try await resolver.refresh()
let snapshot = resolver.snapshot(for: AppFeature.allCases)

// App-owned adapter (mirrors TGReduxKit Shopping FeatureFlagFetching):
// map snapshot → domain DTO, then middleware dispatches .loaded(dto, now())
```

Illustrative adapter (lives in the app, not this package):

```swift
struct TGFFFetchingAdapter: FeatureFlagFetching {
    let resolver: FeatureFlagResolver

    func fetchSnapshot() async -> AppFeatureFlagSnapshot {
        _ = await resolver.refresh()
        let remote = resolver.snapshot(for: AppFeature.allCases)
        return AppFeatureFlagSnapshot(
            isNewProfileEnabled: remote.isEnabled(AppFeature.newProfileDesign)
            // ...map other keys
        )
    }
}

// Composition Root (TGReduxKit 5.0.1 style):
// makeFeatureFlagsMiddleware(featureFlags: adapter, now: { Date() })
```

SwiftUI with an injected snapshot (no `FeatureFlagService`):

```swift
FeatureGate(AppFeature.newProfileDesign, snapshot: storeState.flags) {
    NewProfileView()
} fallback: {
    LegacyProfileView()
}
```

### 2b. Non-Redux path — FeatureFlagService

```swift
@main
struct MyApp: App {
    @State private var service = FeatureFlagService()

    init() {
        let s = FeatureFlagService()
        s.register(provider: DebugProvider(), priority: .highest)
        s.register(provider: LocalProvider(flags: [
            AppFeature.newProfileDesign.lookupKey: .bool(true)
        ]), priority: .lowest)
        _service = State(initialValue: s)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .featureFlagService(service)
        }
    }
}
```

```swift
FeatureGate(AppFeature.newProfileDesign) {
    NewProfileView()
} fallback: {
    LegacyProfileView()
}

let url = service.value(for: AppConfig.apiBaseUrl)
let enabled = service.isEnabled(AppFeature.newProfileDesign)
```

### 3. Async remote provider

```swift
final class MyRemoteProvider: AsyncFeatureFlagProvider, Sendable {
    let name = "Remote"
    private let lock = OSAllocatedUnfairLock(initialState: [String: FeatureFlagValue]())

    func value(for key: String) -> FeatureFlagValue? {
        lock.withLock { $0[key] }
    }

    func fetchValues() async throws {
        // fetch + lock.withLock { $0 = mapped }
    }
}
```

Providers refresh concurrently, so three 100 ms sources cost roughly 100 ms rather than 300 ms. Each provider gets its own timeout, and one hanging source cannot delay the rest:

```swift
let report = try await resolver.refresh(timeout: .seconds(10))

if report.isSuccess {
    // every provider refreshed
} else {
    for outcome in report.outcomes where !outcome.didRefresh {
        // outcome.providerName + outcome.result tells you which source failed and how
    }
}
```

Provider failures come back in the report rather than being thrown, so one broken source never prevents the others from refreshing. Only cancellation is thrown, because that belongs to the caller.

### 4. Grouped keys

```swift
enum CheckoutFeature: String, FeatureFlagKey, GroupedFeatureFlag {
    case v2Flow
    var defaultValue: FeatureFlagValue { .bool(false) }
    static var group: FeatureFlagGroup { FeatureFlagGroup(prefix: "checkout") }
}

// lookupKey == "checkout.v2Flow" for providers, debug overrides, and rollouts
```

### 5. Rollouts

```swift
let rollout = RolloutProvider(userId: userId)
rollout.setRollout(for: AppFeature.newProfileDesign, percentage: 25)
// 0% returns .bool(false) (does not fall through); 100% returns .bool(true)
```

Percentages configured in code still need a release to change, which defeats the point. To drive them from a backend, use `RemoteRolloutProvider` and push the document:

```swift
let remote = RemoteRolloutProvider(userId: userId)
resolver.register(provider: remote, priority: .custom(80))

// Later, whenever the payload arrives:
try remote.apply(json: payload)   // operators moving 5% → 50% no longer ship a build
```

```json
{
  "rollouts": {
    "checkout.v2_flow": { "percentage": 25 },
    "config_banner_text": { "percentage": 50, "value": "Try the new checkout" }
  }
}
```

`value` accepts a bare literal (`true`, `3`, `"text"`, `1.5`) so the document is writable by hand. Applying a document replaces the whole rollout set — a flag that disappears from the payload stops rolling out instead of keeping its last percentage. Malformed entries are skipped and listed in `ignoredKeys` rather than failing the entire document.

One asymmetry is worth knowing: `JSONDecoder` erases the decimal point, so `1.0`, `1e3` and `1` all arrive as integers. A `Double` flag therefore accepts an integer and widens it, reporting `valueWidened`; an `Int` flag still rejects `1.5` rather than truncating it. Keep integral configuration inside `Int`'s range — beyond it the literal decodes as a double and loses precision past 2^53.

Changing the percentage at runtime republishes a change, so the UI updates without a restart. Changing `userId` re-buckets.

### 6. Cold start without a flash

By default every launch starts from `defaultValue` and jumps to the remote values once a refresh lands, so users watch the interface change under them. Persist the last good snapshot and prime the chain from disk:

```swift
let store = LastKnownGoodStore(namespace: "app")

// Launch, before any network call:
if let cached = store.load() {
    resolver.register(
        provider: CachedSnapshotProvider(snapshot: cached),
        priority: .custom(10)   // below remote, above local defaults
    )
}

// After a refresh succeeds:
try? store.save(resolver.snapshot(for: AppFeature.allCases))
```

`load()` never throws: a missing, truncated, or unrecognised file returns `nil`, so a bad cache degrades to defaults instead of failing the launch. Writes are atomic, so an interrupted write cannot leave a half file behind.

### 7. Events and exposures

```swift
final class MySink: FeatureFlagEventSink {
    func receive(_ event: FeatureFlagEvent) {
        switch event {
        case .exposure(let flag, let value):
            analytics.recordExposure(flag: flag, value: value)
        case .typeMismatch(let flag, let expected, let actual):
            logger.warning("flag \(flag) expected \(expected), got \(actual)")
        case .valueWidened(let flag, let expected, let actual):
            // Accepted, not rejected: an integer read as a Double (see the rollout payload note).
            logger.debug("flag \(flag): \(actual) widened to \(expected)")
        case .refreshFailed(let provider, let reason):
            logger.warning("\(provider) failed: \(reason)")
        case .refreshTimedOut(let provider):
            logger.warning("\(provider) timed out")
        case .refreshed:
            break
        case .resolved:
            break   // per-read; only emitted when .resolutions is enabled
        }
    }
}

resolver.setEventSink(MySink())                       // .standard: exposures, refresh, mismatches
resolver.setEventSink(MySink(), options: .all)        // adds a per-read .resolved event
```

Exposures are deduplicated per flag and value, so a view that reads a flag on every frame still reports one exposure. Type mismatches and widenings are deduplicated per flag, expected type and offending value: a flag stays misconfigured for the whole session, so re-reporting it on every read would flood the sink without adding information. Call `startNewSession()` at a session boundary to report them again.

`.resolutions` is excluded from `.standard` on purpose: it fires on every read. The other two read-path events are deduplicated, so `.standard` is safe to leave on in production.

## Resolution order

Providers are sorted by priority (highest first). The first non-`nil` value wins; otherwise `defaultValue` is used. All mutable overrides use `lookupKey` (qualified for grouped flags).

**Ties:** when two providers share the same priority, the **first registered** one wins. Registration order only breaks ties — it never overrides priority. This is covered by tests, so reordering the insert logic can't silently change resolution.

## Snapshot JSON format

`FeatureFlagSnapshot` and `FeatureFlagValue` encode to an explicit, tagged shape:

```json
{
  "values": {
    "feature_new_home": { "type": "bool", "value": true },
    "config_retry_count": { "type": "int", "value": 3 }
  }
}
```

The type tag is deliberate, not incidental. An untagged `{"value": true}` form would be ambiguous on the way back: JSON `1` decodes as an integer, so `.double(1.0)` would silently round-trip into `.int(1)`. The tag keeps the round trip lossless and is simple enough for a backend to produce by hand. Unknown tags fail decoding with a descriptive error rather than falling back to a default.

Snapshots are immutable once built — `values` is read-only, so a dispatched snapshot cannot drift underneath the Store.

## License

See repository license file.
