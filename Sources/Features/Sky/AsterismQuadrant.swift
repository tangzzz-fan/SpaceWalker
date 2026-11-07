import Foundation

/// 二十八宿按四象分组。这是标准划分：每象七宿，顺序固定。
enum MansionQuadrant: String, CaseIterable, Identifiable {
    case azure = "东方苍龙"
    case black = "北方玄武"
    case white = "西方白虎"
    case vermilion = "南方朱雀"

    var id: String { rawValue }

    var mansions: [String] {
        switch self {
        case .azure: return ["角", "亢", "氐", "房", "心", "尾", "箕"]
        case .black: return ["斗", "牛", "女", "虚", "危", "室", "壁"]
        case .white: return ["奎", "娄", "胃", "昴", "毕", "觜", "参"]
        case .vermilion: return ["井", "鬼", "柳", "星", "张", "翼", "轸"]
        }
    }

    static func quadrant(forMansion mansion: String) -> MansionQuadrant? {
        allCases.first { $0.mansions.contains(mansion) }
    }
}

extension Asterism {
    /// 宿名去掉「宿」字；不是二十八宿则为 nil。
    var mansion: String? {
        guard isMansion else { return nil }
        return String(name.dropLast())
    }

    var quadrant: MansionQuadrant? {
        mansion.flatMap(MansionQuadrant.quadrant(forMansion:))
    }
}

enum AsterismBrowse {
    /// 二十八宿按四象顺序、其他星官按成员数与名字排——目录要稳定，不能每次打开顺序都变。
    static func sections(from all: [Asterism]) -> [(title: String, items: [Asterism])] {
        var result: [(String, [Asterism])] = []
        for quadrant in MansionQuadrant.allCases {
            let items = quadrant.mansions.compactMap { mansion in
                all.first { $0.name == "\(mansion)宿" }
            }
            if !items.isEmpty { result.append((quadrant.rawValue, items)) }
        }
        let others = all
            .filter { $0.quadrant == nil }
            .sorted {
                $0.members.count == $1.members.count
                    ? $0.name < $1.name
                    : $0.members.count > $1.members.count
            }
        if !others.isEmpty { result.append(("其他星官", others)) }
        return result
    }
}
