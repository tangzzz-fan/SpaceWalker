import Foundation

struct StarAsterism: Equatable, Sendable {
    var name: String
    var index: Int?
    var mansion: String?
    var symbol: String?
}

enum TwentyEightMansions {
    static let groups: [(symbol: String, mansions: [String])] = [
        ("东方青龙", ["角", "亢", "氐", "房", "心", "尾", "箕"]),
        ("北方玄武", ["斗", "牛", "女", "虚", "危", "室", "壁"]),
        ("西方白虎", ["奎", "娄", "胃", "昴", "毕", "觜", "参"]),
        ("南方朱雀", ["井", "鬼", "柳", "星", "张", "翼", "轸"]),
    ]

    static func symbol(forMansion mansion: String) -> String? {
        groups.first { $0.mansions.contains(mansion) }?.symbol
    }

    static func mansion(fromAsterism name: String) -> String? {
        guard name.hasSuffix("宿") else { return nil }
        let trimmed = String(name.dropLast())
        guard trimmed.count == 1, symbol(forMansion: trimmed) != nil else { return nil }
        return name
    }
}

enum AsterismParser {
    static let beidou: [String: Int] = [
        "天枢": 1, "天璇": 2, "天玑": 3, "天权": 4, "玉衡": 5, "开阳": 6, "摇光": 7,
    ]

    static func asterism(for chineseName: String) -> StarAsterism? {
        if let index = beidou[chineseName] {
            return StarAsterism(name: "北斗", index: index, mansion: nil, symbol: nil)
        }
        if chineseName == "辅" {
            return StarAsterism(name: "北斗", index: nil, mansion: nil, symbol: nil)
        }
        guard let split = splitTrailingNumber(chineseName), split.prefix.count >= 2 else {
            return nil
        }
        let mansion = TwentyEightMansions.mansion(fromAsterism: split.prefix)
        return StarAsterism(
            name: split.prefix,
            index: split.number,
            mansion: mansion,
            symbol: mansion.flatMap { TwentyEightMansions.symbol(forMansion: String($0.dropLast())) }
        )
    }

    static func splitTrailingNumber(_ text: String) -> (prefix: String, number: Int)? {
        var suffix = ""
        var rest = text
        while let last = rest.last, isNumeral(last) {
            suffix = String(last) + suffix
            rest.removeLast()
        }
        guard !suffix.isEmpty, !rest.isEmpty, let number = number(from: suffix) else { return nil }
        return (rest, number)
    }

    static func isNumeral(_ character: Character) -> Bool {
        "一二三四五六七八九十".contains(character)
    }

    static func number(from text: String) -> Int? {
        let digits: [Character: Int] = [
            "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
            "六": 6, "七": 7, "八": 8, "九": 9,
        ]
        if text == "十" { return 10 }
        if let range = text.range(of: "十") {
            let tensPart = String(text[text.startIndex..<range.lowerBound])
            let onesPart = String(text[range.upperBound...])
            let tens = tensPart.isEmpty ? 1 : (digits[tensPart.first!] ?? 0)
            let ones = onesPart.isEmpty ? 0 : (digits[onesPart.first!] ?? 0)
            guard tens > 0, onesPart.count <= 1 else { return nil }
            return tens * 10 + ones
        }
        guard text.count == 1, let value = digits[text.first!] else { return nil }
        return value
    }
}

struct StarDisplay: Equatable, Sendable {
    var title: String
    var subtitle: String?
    var official: Bool
    var asterism: StarAsterism?
    var constellation: String

    var isChinesePrimary: Bool {
        subtitle != nil
    }

    var asterismLine: String? {
        guard let asterism else { return nil }
        if let index = asterism.index {
            return "星官 \(asterism.name) · 第 \(index) 星"
        }
        return "星官 \(asterism.name)"
    }

    var fengshenLine: String? {
        guard let asterism else { return nil }
        let lords = FengshenInfo.lords(forAsterism: asterism.name)
        if lords.count == 1 {
            return "封神 \(lords[0].title) · \(lords[0].person)"
        }
        if lords.count > 1 {
            return "封神 \(lords.count) 位星君"
        }
        return nil
    }

    var mansionLine: String? {
        guard let asterism, let mansion = asterism.mansion else { return nil }
        let symbol = asterism.symbol ?? ""
        return "二十八宿 \(mansion) · \(symbol)"
    }

    static func make(for star: Star) -> StarDisplay {
        let chinese = ChineseStarNames.chinese(for: star.name)
        return StarDisplay(
            title: chinese ?? (star.name.isEmpty ? "未命名恒星" : star.name),
            subtitle: chinese == nil ? nil : star.name,
            official: ChineseStarNames.isOfficial(star.name),
            asterism: chinese.flatMap(AsterismParser.asterism(for:)),
            constellation: ConstellationNames.chinese(for: star.constellation) ?? star.constellation
        )
    }
}
