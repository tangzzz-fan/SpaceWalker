import Foundation

struct FengshenMansion: Equatable, Sendable {
    var mansion: String
    var lord: String
    var person: String
    var department: String?
}

enum FengshenInfo {
    static let table: [String: FengshenMansion] = [
        "角": FengshenMansion(mansion: "角", lord: "角木蛟", person: "柏林", department: nil),
        "亢": FengshenMansion(mansion: "亢", lord: "亢金龙", person: "李道通", department: nil),
        "氐": FengshenMansion(mansion: "氐", lord: "氐土貉", person: "高丙", department: nil),
        "房": FengshenMansion(mansion: "房", lord: "房日兔", person: "姚公伯", department: nil),
        "心": FengshenMansion(mansion: "心", lord: "心月狐", person: "苏元", department: nil),
        "尾": FengshenMansion(mansion: "尾", lord: "尾火虎", person: "朱晤", department: "火部"),
        "箕": FengshenMansion(mansion: "箕", lord: "箕水豹", person: "杨真", department: "水部"),
        "斗": FengshenMansion(mansion: "斗", lord: "斗木獬", person: "杨信", department: nil),
        "牛": FengshenMansion(mansion: "牛", lord: "牛金牛", person: "李弘", department: nil),
        "女": FengshenMansion(mansion: "女", lord: "女土蝠", person: "郑元", department: nil),
        "虚": FengshenMansion(mansion: "虚", lord: "虚日鼠", person: "周宝", department: nil),
        "危": FengshenMansion(mansion: "危", lord: "危月燕", person: "侯太乙", department: nil),
        "室": FengshenMansion(mansion: "室", lord: "室火猪", person: "高震", department: "火部"),
        "壁": FengshenMansion(mansion: "壁", lord: "壁水貐", person: "方吉清", department: "水部"),
        "奎": FengshenMansion(mansion: "奎", lord: "奎木狼", person: "李雄", department: nil),
        "娄": FengshenMansion(mansion: "娄", lord: "娄金狗", person: "张雄", department: nil),
        "胃": FengshenMansion(mansion: "胃", lord: "胃土雉", person: "宋庚", department: nil),
        "昴": FengshenMansion(mansion: "昴", lord: "昴日鸡", person: "黄仓", department: nil),
        "毕": FengshenMansion(mansion: "毕", lord: "毕月乌", person: "金绳阳", department: nil),
        "觜": FengshenMansion(mansion: "觜", lord: "觜火猴", person: "方贵", department: "火部"),
        "参": FengshenMansion(mansion: "参", lord: "参水猿", person: "孙祥", department: "水部"),
        "井": FengshenMansion(mansion: "井", lord: "井木犴", person: "沈庚", department: nil),
        "鬼": FengshenMansion(mansion: "鬼", lord: "鬼金羊", person: "赵白高", department: nil),
        "柳": FengshenMansion(mansion: "柳", lord: "柳土獐", person: "吴坤", department: nil),
        "星": FengshenMansion(mansion: "星", lord: "星日马", person: "吕能", department: nil),
        "张": FengshenMansion(mansion: "张", lord: "张月鹿", person: "薛定", department: nil),
        "翼": FengshenMansion(mansion: "翼", lord: "翼火蛇", person: "王蛟", department: "火部"),
        "轸": FengshenMansion(mansion: "轸", lord: "轸水蚓", person: "胡道元", department: "水部"),
    ]

    static let beidouLords = ["贪狼", "巨门", "禄存", "文曲", "廉贞", "武曲", "破军"]

    static func entry(forMansion mansion: String) -> FengshenMansion? {
        guard mansion.hasSuffix("宿") else { return nil }
        return table[String(mansion.dropLast())]
    }

    static func entry(forAsterism name: String) -> FengshenMansion? {
        table[name]
    }

    static let sourceNote = "名号与人物据《封神演义》第九十九回姜子牙封神；其中尾、箕、室、壁、觜、参、翼、轸八人分在水、火二部。各版本人名偶有出入。"
}
