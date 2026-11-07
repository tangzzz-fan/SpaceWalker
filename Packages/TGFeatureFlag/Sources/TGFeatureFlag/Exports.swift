// Umbrella module.
//
// `TGFeatureFlagCore` has no SwiftUI dependency: it can be consumed by background agents,
// app extensions, watch complications or plain logic modules without dragging in view code.
// `TGFeatureFlagSwiftUI` adds the gates and the debug screen on top.
//
// Re-exporting both keeps `import TGFeatureFlag` working, so splitting the package is not a
// source-breaking change for existing callers. Import the specific module instead when you
// want the dependency to be explicit.

@_exported import TGFeatureFlagCore
@_exported import TGFeatureFlagSwiftUI
