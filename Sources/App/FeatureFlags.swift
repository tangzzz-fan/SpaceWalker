import Foundation
import TGFeatureFlag

/// 内容按「认知负荷」分档，而不是按功能拆。
/// base 档没有开关——星表、星座线、准星选中缺了产品不成立。
enum AppFeature: String, TypedFeatureFlag, CaseIterable {
    case contentCulture = "spacewalker.content.culture"
    case contentDeep = "spacewalker.content.deep"

    var typedDefaultValue: Bool {
        switch self {
        case .contentCulture: true
        case .contentDeep: false
        }
    }

    /// 本地覆盖，方便验收深档内容而不改远端：`SPACEWALKER_FLAG_DEEP=1`。
    var overrideKey: String {
        let suffix = rawValue.split(separator: ".").last.map { String($0).uppercased() } ?? ""
        return "SPACEWALKER_FLAG_" + suffix
    }

    var isOverridden: Bool {
        ProcessInfo.processInfo.environment[overrideKey] != nil
    }

    var overrideValue: Bool {
        ProcessInfo.processInfo.environment[overrideKey] == "1"
    }
}

struct FeatureFlags: Equatable, Sendable {
    /// 文化层：星官连线、星座释义、封神星榜。
    var cultureEnabled = true
    /// 深度层：星群、今夜导览、水浒对照。
    var deepEnabled = false
}
