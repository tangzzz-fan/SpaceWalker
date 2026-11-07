import SwiftUI
import TGFeatureFlagCore

/// A debug screen listing every flag with an editor for its current value.
///
/// Two sources, mirroring the two supported modes:
///
/// - **Snapshot** (Redux / Store-as-SoT): pass the snapshot the Store holds plus an
///   `onOverride` callback. The screen never writes state itself; the app decides what an
///   override means for its Store.
/// - **Service** (non-Redux): inject `FeatureFlagService` with `.featureFlagService(_:)` and
///   omit the snapshot. Edits go into the registered `DebugProvider`.
///
/// An explicit snapshot wins over the environment service — the same precedence `FeatureGate`
/// uses. With neither source the screen explains the mistake instead of trapping, so a debug
/// screen can no longer crash the app it was meant to debug.
public struct FeatureFlagDebugView<F: FeatureFlagKey & CaseIterable>: View {
    @Environment(\.featureFlagService) private var service

    private let snapshot: FeatureFlagSnapshot?
    private let overriddenKeys: Set<String>
    private let onOverride: FeatureFlagOverrideHandler?

    /// Service-driven screen, for non-Redux apps.
    public init() {
        self.snapshot = nil
        self.overriddenKeys = []
        self.onOverride = nil
    }

    /// Snapshot-driven screen, for Redux apps.
    ///
    /// - Parameters:
    ///   - snapshot: The snapshot held by the Store.
    ///   - overriddenKeys: Keys the app currently treats as overridden. A snapshot is a
    ///     resolved result, so it cannot say whether a value came from an override; the app
    ///     supplies that fact rather than the screen guessing.
    ///   - onOverride: Receives `(lookupKey, value)`; `nil` clears the override.
    public init(
        snapshot: FeatureFlagSnapshot,
        overriddenKeys: Set<String> = [],
        onOverride: @escaping FeatureFlagOverrideHandler
    ) {
        self.snapshot = snapshot
        self.overriddenKeys = overriddenKeys
        self.onOverride = onOverride
    }

    private var hasSource: Bool { snapshot != nil || service != nil }

    private var debugProvider: DebugProvider? { service?.provider(ofType: DebugProvider.self) }

    private var canResetAll: Bool { debugProvider != nil || !overriddenKeys.isEmpty }

    public var body: some View {
        List {
            if hasSource {
                Section("Feature Flags") {
                    ForEach(Array(F.allCases), id: \.self) { feature in
                        FlagRow(
                            feature: feature,
                            model: model(for: feature),
                            onEdit: { apply($0, to: feature) }
                        )
                    }
                }

                if canResetAll {
                    Section {
                        Button("Reset All Overrides") { resetAll() }
                            .foregroundStyle(.red)
                    }
                }
            } else {
                Section {
                    Text(
                        """
                        No flag source. Pass `snapshot:` or apply \
                        `.featureFlagService(_:)` at the root of the hierarchy.
                        """
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Feature Flags")
    }

    private func model(for feature: F) -> FeatureFlagDebugEditorModel {
        FeatureFlagDebugEditorModel(
            defaultValue: feature.defaultValue,
            resolved: FeatureFlagDebugResolution.value(
                for: feature,
                snapshot: snapshot,
                service: service
            ),
            isOverridden: FeatureFlagDebugResolution.isOverridden(
                for: feature,
                overriddenKeys: overriddenKeys,
                debugProvider: debugProvider
            )
        )
    }

    /// A snapshot plus its callback owns the write path; otherwise the edit lands in the
    /// `DebugProvider` the service resolved.
    private func apply(_ value: FeatureFlagValue?, to feature: F) {
        if let onOverride {
            onOverride(feature.lookupKey, value)
        } else {
            debugProvider?.setOverride(for: feature, value: value)
        }
    }

    private func resetAll() {
        if let debugProvider {
            debugProvider.reset()
            return
        }
        // Sorted so a bulk reset dispatches in a stable order, which keeps snapshot
        // assertions deterministic in tests.
        for key in overriddenKeys.sorted() {
            onOverride?(key, nil)
        }
    }
}

private struct FlagRow<F: FeatureFlagKey>: View {
    let feature: F
    let model: FeatureFlagDebugEditorModel
    let onEdit: (FeatureFlagValue?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.description)
                        .font(.headline)
                    Text(feature.lookupKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if model.isOverridden {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Overridden")
                }
            }

            if model.hasTypeMismatch {
                Label(
                    "Stored \(model.currentValueDescription) does not match the declared type.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            if model.isWidened {
                Label(
                    "Stored \(model.currentValueDescription) as a Double.",
                    systemImage: "arrow.left.arrow.right"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            switch model.kind {
            case .bool:
                BoolEditor(model: model, onEdit: onEdit)
            case .string:
                StringEditor(model: model, onEdit: onEdit)
            case .int:
                IntEditor(model: model, onEdit: onEdit)
            case .double:
                DoubleEditor(model: model, onEdit: onEdit)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Shared reset affordance: writes `nil` so the flag falls through to the next provider
/// rather than pinning it to the default — the two are only the same value when nothing else
/// supplies one.
private struct ResetButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Reset override")
    }
}

private struct BoolEditor: View {
    let model: FeatureFlagDebugEditorModel
    let onEdit: (FeatureFlagValue?) -> Void
    @State private var localValue: Bool

    init(model: FeatureFlagDebugEditorModel, onEdit: @escaping (FeatureFlagValue?) -> Void) {
        self.model = model
        self.onEdit = onEdit
        _localValue = State(initialValue: model.currentValue.boolValue ?? false)
    }

    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { localValue },
                set: { newValue in
                    localValue = newValue
                    onEdit(.bool(newValue))
                }
            )) {
                Text(localValue ? "ON" : "OFF")
                    .bold()
                    .foregroundStyle(localValue ? .green : .red)
            }

            if model.isOverridden {
                ResetButton {
                    localValue = model.defaultValue.boolValue ?? localValue
                    onEdit(nil)
                }
            }
        }
        .onChange(of: model.currentValue) { _, _ in
            localValue = model.currentValue.boolValue ?? localValue
        }
    }
}

private struct IntEditor: View {
    let model: FeatureFlagDebugEditorModel
    let onEdit: (FeatureFlagValue?) -> Void
    @State private var localValue: Int

    init(model: FeatureFlagDebugEditorModel, onEdit: @escaping (FeatureFlagValue?) -> Void) {
        self.model = model
        self.onEdit = onEdit
        _localValue = State(initialValue: model.currentValue.intValue ?? 0)
    }

    var body: some View {
        HStack {
            Stepper(value: Binding(
                get: { localValue },
                set: { newValue in
                    localValue = newValue
                    onEdit(.int(newValue))
                }
            )) {
                HStack {
                    Text("Value:")
                        .foregroundStyle(.secondary)
                    Text("\(localValue)")
                        .bold()
                        .monospacedDigit()
                }
            }

            if model.isOverridden {
                ResetButton {
                    localValue = model.defaultValue.intValue ?? localValue
                    onEdit(nil)
                }
            }
        }
        .onChange(of: model.currentValue) { _, _ in
            localValue = model.currentValue.intValue ?? localValue
        }
    }
}

private struct DoubleEditor: View {
    let model: FeatureFlagDebugEditorModel
    let onEdit: (FeatureFlagValue?) -> Void
    @State private var localValue: Double

    init(model: FeatureFlagDebugEditorModel, onEdit: @escaping (FeatureFlagValue?) -> Void) {
        self.model = model
        self.onEdit = onEdit
        _localValue = State(initialValue: model.currentValue.doubleValue ?? 0)
    }

    var body: some View {
        HStack {
            TextField("Value", value: Binding(
                get: { localValue },
                set: { newValue in
                    localValue = newValue
                    onEdit(.double(newValue))
                }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif

            Text(String(format: "%.2f", localValue))
                .bold()
                .monospacedDigit()
                .frame(minWidth: 60, alignment: .trailing)

            if model.isOverridden {
                ResetButton {
                    localValue = model.defaultValue.doubleValue ?? localValue
                    onEdit(nil)
                }
            }
        }
        .onChange(of: model.currentValue) { _, _ in
            localValue = model.currentValue.doubleValue ?? localValue
        }
    }
}

private struct StringEditor: View {
    let model: FeatureFlagDebugEditorModel
    let onEdit: (FeatureFlagValue?) -> Void
    @State private var localValue: String

    init(model: FeatureFlagDebugEditorModel, onEdit: @escaping (FeatureFlagValue?) -> Void) {
        self.model = model
        self.onEdit = onEdit
        _localValue = State(initialValue: model.currentValue.stringValue ?? "")
    }

    var body: some View {
        HStack {
            TextField("Value", text: Binding(
                get: { localValue },
                set: { newValue in
                    localValue = newValue
                    onEdit(.string(newValue))
                }
            ))
            .textFieldStyle(.roundedBorder)

            if model.isOverridden {
                ResetButton {
                    localValue = model.defaultValue.stringValue ?? localValue
                    onEdit(nil)
                }
            }
        }
        .onChange(of: model.currentValue) { _, _ in
            localValue = model.currentValue.stringValue ?? localValue
        }
    }
}
