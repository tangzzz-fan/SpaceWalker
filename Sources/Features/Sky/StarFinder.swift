import Foundation

struct StarAlias: Equatable, Sendable {
    var starName: String
    var chinese: String
    var official: Bool
}

enum ChineseStarNames {
    static let table: [String: String] = [
        "Sirius": "天狼",
        "Canopus": "老人",
        "Arcturus": "大角",
        "Rigil Kentaurus": "南门二",
        "Vega": "织女一",
        "Capella": "五车二",
        "Rigel": "参宿七",
        "Procyon": "南河三",
        "Achernar": "水委一",
        "Betelgeuse": "参宿四",
        "Hadar": "马腹一",
        "Altair": "河鼓二",
        "Acrux": "十字架二",
        "Aldebaran": "毕宿五",
        "Antares": "心宿二",
        "Spica": "角宿一",
        "Pollux": "北河三",
        "Fomalhaut": "北落师门",
        "Deneb": "天津四",
        "Mimosa": "十字架三",
        "Regulus": "轩辕十四",
        "Adhara": "弧矢七",
        "Castor": "北河二",
        "Gacrux": "十字架一",
        "Bellatrix": "参宿五",
        "Elnath": "五车五",
        "Miaplacidus": "南船五",
        "Alnilam": "参宿二",
        "Alnair": "鹤一",
        "Alnitak": "参宿一",
        "Mintaka": "参宿三",
        "Saiph": "参宿六",
        "Meissa": "觜宿一",
        "Alioth": "玉衡",
        "Dubhe": "天枢",
        "Merak": "天璇",
        "Phecda": "天玑",
        "Megrez": "天权",
        "Mizar": "开阳",
        "Alkaid": "摇光",
        "Alcor": "辅",
        "Polaris": "勾陈一",
        "Kochab": "北极二",
        "Pherkad": "北极一",
        "Thuban": "右枢",
        "Eltanin": "天棓四",
        "Rastaban": "天棓三",
        "Edasich": "左枢",
        "Mirfak": "天船三",
        "Wezen": "弧矢一",
        "Aludra": "弧矢二",
        "Sargas": "尾宿五",
        "Shaula": "尾宿八",
        "Kaus Australis": "箕宿三",
        "Kaus Media": "箕宿二",
        "Kaus Borealis": "斗宿二",
        "Alnasl": "箕宿一",
        "Nunki": "斗宿四",
        "Avior": "海石一",
        "Menkalinan": "五车三",
        "Mahasim": "五车四",
        "Hassaleh": "五车一",
        "Atria": "三角形三",
        "Alhena": "井宿三",
        "Peacock": "孔雀十一",
        "Mirzam": "军市一",
        "Alphard": "星宿一",
        "Hamal": "娄宿三",
        "Sheratan": "娄宿一",
        "Mesarthim": "娄宿二",
        "Algieba": "轩辕十二",
        "Adhafera": "轩辕十一",
        "Dschubba": "房宿三",
        "Acrab": "房宿四",
        "Rasalhague": "侯",
        "Rasalgethi": "帝座",
        "Kornephoros": "河中",
        "Sabik": "天市右垣十一",
        "Unukalhai": "天市右垣七",
        "Izar": "梗河一",
        "Seginus": "招摇",
        "Muphrid": "右摄提二",
        "Algol": "大陵五",
        "Alpheratz": "壁宿二",
        "Mirach": "奎宿九",
        "Almach": "天大将军一",
        "Markab": "室宿一",
        "Scheat": "室宿二",
        "Algenib": "壁宿一",
        "Homam": "危宿二",
        "Matar": "离宫四",
        "Enif": "危宿三",
        "Sadr": "天津一",
        "Albireo": "辇道增七",
        "Sheliak": "渐台二",
        "Sulafat": "渐台三",
        "Tarazed": "河鼓三",
        "Alshain": "河鼓一",
        "Denebola": "五帝座一",
        "Alcyone": "昴宿六",
        "Atlas": "昴宿七",
        "Electra": "昴宿一",
        "Maia": "昴宿四",
        "Merope": "昴宿五",
        "Taygeta": "昴宿二",
        "Ain": "毕宿一",
        "Gomeisa": "南河二",
        "Menkar": "天囷一",
        "Diphda": "土司空",
        "Zubeneschamali": "氐宿四",
        "Zubenelgenubi": "氐宿一",
        "Dabih": "牛宿一",
        "Deneb Algedi": "垒壁阵四",
        "Nashira": "垒壁阵三",
        "Alderamin": "天钩五",
        "Porrima": "东上相",
        "Vindemiatrix": "东次将",
        "Heze": "东次相",
        "Caph": "王良一",
        "Schedar": "王良四",
        "Ruchbah": "阁道三",
        "Gienah": "轸宿一",
        "Algorab": "轸宿三",
        "Kraz": "轸宿四",
        "Imai": "十字架四",
        "Tianguan": "天关",
        "Xuange": "玄戈",
        "Tianyi": "天一",
        "Fuyue": "傅说",
    ]

    static let officialChineseNames: Set<String> = ["Tianguan", "Xuange", "Tianyi", "Fuyue"]

    static let queryAliases: [String: String] = [
        "天狼星": "Sirius",
        "牛郎": "Altair",
        "牛郎星": "Altair",
        "织女星": "Vega",
        "北极星": "Polaris",
        "帝星": "Polaris",
        "老人星": "Canopus",
        "大角星": "Arcturus",
        "五车二": "Capella",
        "天津四": "Deneb",
    ]

    static func chinese(for starName: String) -> String? {
        table[starName]
    }

    static func isOfficial(_ starName: String) -> Bool {
        officialChineseNames.contains(starName)
    }
}

enum ConstellationNames {
    static let table: [String: String] = [
        "And": "仙女座", "Ant": "唧筒座", "Aps": "天燕座", "Aqr": "宝瓶座", "Aql": "天鹰座",
        "Ara": "天坛座", "Ari": "白羊座", "Aur": "御夫座", "Boo": "牧夫座", "Cae": "雕具座",
        "Cam": "鹿豹座", "Cnc": "巨蟹座", "CVn": "猎犬座", "CMa": "大犬座", "CMi": "小犬座",
        "Cap": "摩羯座", "Car": "船底座", "Cas": "仙后座", "Cen": "半人马座", "Cep": "仙王座",
        "Cet": "鲸鱼座", "Cha": "蝘蜓座", "Cir": "圆规座", "Col": "天鸽座", "Com": "后发座",
        "CrA": "南冕座", "CrB": "北冕座", "Crv": "乌鸦座", "Crt": "巨爵座", "Cru": "南十字座",
        "Cyg": "天鹅座", "Del": "海豚座", "Dor": "剑鱼座", "Dra": "天龙座", "Equ": "小马座",
        "Eri": "波江座", "For": "天炉座", "Gem": "双子座", "Gru": "天鹤座", "Her": "武仙座",
        "Hor": "时钟座", "Hya": "长蛇座", "Hyi": "水蛇座", "Ind": "印第安座", "Lac": "蝎虎座",
        "Leo": "狮子座", "LMi": "小狮座", "Lep": "天兔座", "Lib": "天秤座", "Lup": "豺狼座",
        "Lyn": "天猫座", "Lyr": "天琴座", "Men": "山案座", "Mic": "显微镜座", "Mon": "麒麟座",
        "Mus": "苍蝇座", "Nor": "矩尺座", "Oct": "南极座", "Oph": "蛇夫座", "Ori": "猎户座",
        "Pav": "孔雀座", "Peg": "飞马座", "Per": "英仙座", "Phe": "凤凰座", "Pic": "绘架座",
        "Psc": "双鱼座", "PsA": "南鱼座", "Pup": "船尾座", "Pyx": "罗盘座", "Ret": "网罟座",
        "Sge": "天箭座", "Sgr": "人马座", "Sco": "天蝎座", "Scl": "玉夫座", "Sct": "盾牌座",
        "Ser": "巨蛇座", "Sex": "六分仪座", "Tau": "金牛座", "Tel": "望远镜座", "Tri": "三角座",
        "TrA": "南三角座", "Tuc": "杜鹃座", "UMa": "大熊座", "UMi": "小熊座", "Vel": "船帆座",
        "Vir": "室女座", "Vol": "飞鱼座", "Vul": "狐狸座",
    ]

    static let nicknames: [String: String] = [
        "北斗": "UMa",
        "北斗七星": "UMa",
        "南斗": "Sgr",
        "北天极": "UMi",
        "大火": "Sco",
    ]

    static func chinese(for abbreviation: String) -> String? {
        table[abbreviation]
    }

    static func abbreviation(forNickname nickname: String) -> String? {
        nicknames[nickname]
    }
}

enum StarFinder {
    struct Hit: Equatable, Sendable {
        var star: Star
        var chinese: String?
        var official: Bool
    }

    struct ConstellationGroup: Equatable, Sendable {
        var abbreviation: String
        var name: String
        var stars: [Star]
    }

    static let curatedGroups: [(String, [String])] = [
        ("北斗七星", ["Dubhe", "Merak", "Phecda", "Megrez", "Alioth", "Mizar", "Alkaid"]),
        ("冬季大三角", ["Sirius", "Procyon", "Betelgeuse"]),
        ("夏季大三角", ["Vega", "Deneb", "Altair"]),
        ("猎户腰带", ["Mintaka", "Alnilam", "Alnitak"]),
    ]

    static func hit(for star: Star) -> Hit {
        let chinese = ChineseStarNames.chinese(for: star.name)
        return Hit(star: star, chinese: chinese, official: ChineseStarNames.isOfficial(star.name))
    }

    static func chineseNamed(_ stars: [Star]) -> [Hit] {
        stars
            .filter { $0.isSelectable && ChineseStarNames.chinese(for: $0.name) != nil }
            .sorted { $0.magnitude < $1.magnitude }
            .map(hit(for:))
    }

    static func brightest(_ stars: [Star], limit: Int = 20) -> [Hit] {
        stars
            .filter(\.isSelectable)
            .sorted { $0.magnitude < $1.magnitude }
            .prefix(limit)
            .map(hit(for:))
    }

    static func groups(_ stars: [Star], named: [(String, [String])] = curatedGroups) -> [(String, [Hit])] {
        let index = Dictionary(grouping: stars.filter(\.isSelectable), by: \.name)
        return named.compactMap { title, names in
            let hits = names.compactMap { index[$0]?.first }.map(hit(for:))
            return hits.isEmpty ? nil : (title, hits)
        }
    }

    static func constellations(_ stars: [Star]) -> [ConstellationGroup] {
        let grouped = Dictionary(grouping: stars.filter(\.isSelectable), by: \.constellation)
        return grouped.compactMap { abbreviation, members in
            guard !abbreviation.isEmpty else { return nil }
            return ConstellationGroup(
                abbreviation: abbreviation,
                name: ConstellationNames.chinese(for: abbreviation) ?? abbreviation,
                stars: members.sorted { $0.magnitude < $1.magnitude }
            )
        }
        .sorted { $0.name < $1.name }
    }

    static func search(_ stars: [Star], query rawQuery: String, limit: Int = 40) -> [Hit] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        let aliasName = ChineseStarNames.queryAliases[query]
        let nicknameConstellation = ConstellationNames.abbreviation(forNickname: query)
        var scored: [(hit: Hit, score: Int)] = []

        for star in stars where star.isSelectable {
            let chinese = ChineseStarNames.chinese(for: star.name)
            var best: Int?
            if let aliasName, star.name == aliasName {
                scored.append((hit(for: star), -1))
                continue
            }
            if let nicknameConstellation, star.constellation == nicknameConstellation {
                scored.append((hit(for: star), 4))
                continue
            }
            if star.name.lowercased() == lowered {
                best = 0
            } else if chinese == query {
                best = 0
            } else if star.name.lowercased().hasPrefix(lowered) {
                best = 1
            } else if let chinese, chinese.contains(query) {
                best = 2
            } else if star.name.lowercased().contains(lowered) {
                best = 3
            } else if let name = ConstellationNames.chinese(for: star.constellation), name.contains(query) {
                best = 4
            }
            if let best {
                scored.append((hit(for: star), best))
            }
        }

        return scored
            .sorted { left, right in
                if left.score != right.score { return left.score < right.score }
                return left.hit.star.magnitude < right.hit.star.magnitude
            }
            .prefix(limit)
            .map(\.hit)
    }
}
