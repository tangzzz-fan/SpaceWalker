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

    /// 任务里程碑。只收**有一手来源**的条目——没有出处的漂亮故事不进界面。
    struct Milestone: Equatable, Sendable, Identifiable {
        var id: String { date }
        var date: String
        var title: String
        var detail: String
        var source: String
    }

    static let milestones: [Milestone] = [
        Milestone(
            date: "2012-06-20",
            title: "组合体姿态调整",
            detail: "天宫一号与神舟九号组合体完成第一次姿态调整，从倒飞状态进入正常飞行姿态，"
                + "形成「天宫在后正飞、飞船在前倒飞」的组合体标准飞行模式。",
            source: "中国载人航天工程办公室 · 神舟九号任务第三期通报"
        ),
    ]

    /// 「最后一圈」收束卡。与上方 `facts` 同源，不在别处再写一份文案——
    /// 彩蛋的日期写错比彩蛋本身没有更糟。
    struct Closing: Equatable, Sendable {
        var headline: String
        var date: String
        var place: String
        var body: String
    }

    static var closing: Closing? {
        guard let fact = facts.first(where: { $0.label == "再入" }) else { return nil }
        let parts = fact.value.components(separatedBy: " · ")
        guard parts.count == 2 else { return nil }
        return Closing(
            headline: "再入大气层",
            date: parts[0],
            place: parts[1],
            body: "\(name)于 \(parts[0]) 再入大气层，落区 \(parts[1])。"
        )
    }

    /// 界面禁止出现的称谓。PRD FR-C-01 要求「界面不称其为空间站」。
    static let forbiddenTerms = ["空间站"]

    static var summary: String {
        facts.map { "\($0.label) \($0.value)" }.joined(separator: " · ")
    }
}
