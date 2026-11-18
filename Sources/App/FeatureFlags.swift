import Foundation
import TGFeatureFlag

/// 内容按「认知负荷」分档，而不是按功能拆。
/// base 档没有开关——星表、星座线、准星选中缺了产品不成立。
enum AppFeature: String, TypedFeatureFlag, CaseIterable {
    case contentCulture = "spacewalker.content.culture"
    case contentDeep = "spacewalker.content.deep"

    var typedDefaultValue: Bool {
        switch self {
        case .contentCulture: false
        case .contentDeep: false
        }
    }

    /// 本地覆盖，方便验收深档内容而不改远端：`SPACEWALKER_FLAG_DEEP=1`。
    var overrideKey: String {
        let suffix = rawValue.split(separator: ".").last.map { String($0).uppercased() } ?? ""
        return "SPACEWALKER_FLAG_" + suffix
    }

    func override(environment: [String: String]) -> Bool? {
        guard let raw = environment[overrideKey] else { return nil }
        return raw == "1"
    }

}

struct FeatureFlags: Equatable, Sendable {
    /// 演义文化层：封神星榜、封神名号行、水浒对照。星官与星座释义属天文主线，不受此开关。
    var cultureEnabled = false
    /// 深度层：星群、今夜导览、水浒对照。
    var deepEnabled = false
}
