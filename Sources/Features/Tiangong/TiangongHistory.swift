import Foundation

/// 天宫一号的史实条目。
///
/// 只收 `docs/research/realitykit-ios26-primary-sources.md` 第 15 条里有出处的字段。
/// 尺寸不在这里——它属于几何参数，不是史实条目，混进来会让「零错误」失守。
enum TiangongHistory {
    static let name = "天宫一号"
    static let kind = "目标飞行器 / 空间实验室"

    struct Fact: Equatable, Sendable, Identifiable {
        var id: String { label }
        var label: String
        var value: String
    }

    static let facts: [Fact] = [
        Fact(label: "发射", value: "2011-09-29"),
        Fact(label: "定位", value: "中国首个目标飞行器 / 空间实验室"),
        Fact(label: "交会对接", value: "与神舟八号、九号、十号共 6 次"),
        Fact(label: "终止数据服务", value: "2016-03-16"),
        Fact(label: "再入", value: "2018-04-02 · 南太平洋中部"),
    ]

    /// 界面禁止出现的称谓。PRD FR-C-01 要求「界面不称其为空间站」。
    static let forbiddenTerms = ["空间站"]

    static var summary: String {
        facts.map { "\($0.label) \($0.value)" }.joined(separator: " · ")
    }
}
