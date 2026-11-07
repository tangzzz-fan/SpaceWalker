import TGFeatureFlag

enum AppFeature: String, TypedFeatureFlag, CaseIterable {
    case prototype = "spacewalker.prototype"

    var typedDefaultValue: Bool { false }
}

struct FeatureFlags: Equatable, Sendable {
    var prototypeEnabled: Bool = false
}
