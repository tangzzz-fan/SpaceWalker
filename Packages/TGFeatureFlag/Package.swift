// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TGFeatureFlag",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        // Umbrella product: everything, for callers that just want `import TGFeatureFlag`.
        .library(
            name: "TGFeatureFlag",
            targets: ["TGFeatureFlag"]
        ),
        // Resolution, providers and snapshots — no SwiftUI.
        .library(
            name: "TGFeatureFlagCore",
            targets: ["TGFeatureFlagCore"]
        ),
        // Gates and the debug screen.
        .library(
            name: "TGFeatureFlagSwiftUI",
            targets: ["TGFeatureFlagSwiftUI"]
        ),
    ],
    targets: [
        .target(
            name: "TGFeatureFlagCore"
        ),
        .target(
            name: "TGFeatureFlagSwiftUI",
            dependencies: ["TGFeatureFlagCore"]
        ),
        .target(
            name: "TGFeatureFlag",
            dependencies: ["TGFeatureFlagCore", "TGFeatureFlagSwiftUI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
