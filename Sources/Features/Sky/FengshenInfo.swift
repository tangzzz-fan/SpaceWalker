import Foundation

/// 一位受封正神。名号、人物与所属部据《封神演义》第九十九回。
struct FengshenLord: Identifiable, Equatable, Sendable, Decodable {
    var id: String
    var title: String
    var person: String
    var department: String
    var group: String
    var asterism: String?
    var mansion: String?
    var alsoServes: String?
    var note: String?

    /// 在星图上有对应星官，可直接定位。
    var isLocatable: Bool {
        asterism != nil
    }

    /// 「斗部 · 二十八宿 · 兼火部」
    var affiliation: String {
        var parts = [department]
        if group != department {
            parts.append(group)
        }
        if let alsoServes {
            parts.append("兼\(alsoServes)")
        }
        return parts.joined(separator: " · ")
    }
}

enum FengshenInfo {
    static let resourceName = "fengshen"
    static let all: [FengshenLord] = loadFromBundle()

    static let sourceNote = """
        名号、人物与所属部据《封神演义》第九十九回「姜子牙归国封神」。\
        原文称三百六十五位正神；二十八宿中尾、室、觜、翼与箕、壁、参、轸八人兼领水、火二部，\
        重复列名，故此表条数多于三百六十五。闪电神与助风神原文未具名，据通行本补。
        """

    /// 部门按数据中的出现顺序，用于分组展示。
    static let departments: [String] = {
        var seen = Set<String>()
        return all.compactMap { seen.insert($0.department).inserted ? $0.department : nil }
    }()

    static let departmentNotes: [String: String] = [
        "清福神": "柏鉴执百灵幡守封神台，引诸神循序受封，为八部三百六十五位之首。",
        "三山五岳": "黄飞虎总管天地人间吉凶祸福，兼掌幽冥十八重地狱；五岳分镇五方。",
        "雷部": "闻仲督率二十四员催云助雨护法天君，兴云布雨、诛逆除奸。",
        "火部": "罗宣巡察人间善恶，领尾、室、觜、翼四宿与接火天君。",
        "瘟部": "吕岳主时症，四使分向行瘟，另有劝善大师与和瘟道士。",
        "斗部": "金灵圣母坐镇斗府，居周天列宿之首，八万四千群星恶煞咸听驱使。",
        "水部": "鲁雄掌水德，箕、壁、参、轸四宿兼领，与火部相对。",
        "太岁部": "殷郊执年、杨任值甲子，循周天星宿度数，察人间过往愆由。",
        "四圣": "九龙岛王魔等四人，镇守灵霄宝殿。",
        "财部": "赵公明领四位正神，迎祥纳福、追逃捕亡。",
        "四大天王": "魔家四将辅弼西方教典，分掌风、调、雨、顺。",
        "哼哈二将": "郑伦、陈奇镇守西释山门，宣布教化、保护法宝。",
        "痘部": "余化龙掌人间时症、主生死修短，五子分主五方。",
        "三仙岛": "云霄、琼霄、碧霄执混元金斗，凡生育转劫皆从此过。",
        "分水将军": "申公豹执掌东海，朝观日出，暮转天河，夏散冬凝。",
    ]

    static func lords(in department: String) -> [FengshenLord] {
        all.filter { $0.department == department }
    }

    /// 同一部门内的分组，按出现顺序。
    static func groups(in department: String) -> [String] {
        var seen = Set<String>()
        return lords(in: department).compactMap {
            seen.insert($0.group).inserted ? $0.group : nil
        }
    }

    private static let byMansion: [String: FengshenLord] = {
        var result: [String: FengshenLord] = [:]
        for lord in all {
            guard let mansion = lord.mansion else { continue }
            result[mansion] = lord
        }
        return result
    }()

    private static let byAsterism: [String: [FengshenLord]] = Dictionary(
        grouping: all.filter(\.isLocatable),
        by: { $0.asterism ?? "" }
    )

    /// 接受「参」或「参宿」两种写法。
    static func entry(forMansion mansion: String) -> FengshenLord? {
        let key = mansion.hasSuffix("宿") ? String(mansion.dropLast()) : mansion
        return byMansion[key]
    }

    static func lords(forAsterism asterism: String) -> [FengshenLord] {
        byAsterism[asterism] ?? []
    }

    static func search(_ raw: String) -> [FengshenLord] {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return all.filter { lord in
            lord.title.contains(query)
                || lord.person.contains(query)
                || lord.department.contains(query)
                || lord.group.contains(query)
                || (lord.asterism?.contains(query) ?? false)
        }
    }

    static func decode(_ data: Data) throws -> [FengshenLord] {
        try JSONDecoder().decode(Payload.self, from: data).lords
    }

    static func loadFromBundle(_ bundle: Bundle = .main) -> [FengshenLord] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lords = try? decode(data)
        else {
            return []
        }
        return lords
    }

    private struct Payload: Decodable {
        var source: String
        var note: String
        var lords: [FengshenLord]
    }
}
