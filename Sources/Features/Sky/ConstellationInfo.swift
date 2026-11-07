import Foundation
import simd

struct ConstellationFact: Equatable, Sendable {
    var abbreviation: String
    var westernLore: String
    var chineseLore: String
}

struct ConstellationRegion: Equatable, Identifiable, Sendable {
    var id: String { abbreviation }

    var abbreviation: String
    var chineseName: String
    var latinName: String
    var starCount: Int
    var brightest: Star?
    var bestMonth: Int
    var distance: Double
}

enum ConstellationInfo {
    static let latinNames: [String: String] = [
        "And": "Andromeda", "Ant": "Antlia", "Aps": "Apus", "Aqr": "Aquarius", "Aql": "Aquila",
        "Ara": "Ara", "Ari": "Aries", "Aur": "Auriga", "Boo": "Boötes", "Cae": "Caelum",
        "Cam": "Camelopardalis", "Cnc": "Cancer", "CVn": "Canes Venatici", "CMa": "Canis Major",
        "CMi": "Canis Minor", "Cap": "Capricornus", "Car": "Carina", "Cas": "Cassiopeia",
        "Cen": "Centaurus", "Cep": "Cepheus", "Cet": "Cetus", "Cha": "Chamaeleon",
        "Cir": "Circinus", "Col": "Columba", "Com": "Coma Berenices", "CrA": "Corona Australis",
        "CrB": "Corona Borealis", "Crv": "Corvus", "Crt": "Crater", "Cru": "Crux",
        "Cyg": "Cygnus", "Del": "Delphinus", "Dor": "Dorado", "Dra": "Draco",
        "Equ": "Equuleus", "Eri": "Eridanus", "For": "Fornax", "Gem": "Gemini",
        "Gru": "Grus", "Her": "Hercules", "Hor": "Horologium", "Hya": "Hydra",
        "Hyi": "Hydrus", "Ind": "Indus", "Lac": "Lacerta", "Leo": "Leo",
        "LMi": "Leo Minor", "Lep": "Lepus", "Lib": "Libra", "Lup": "Lupus",
        "Lyn": "Lynx", "Lyr": "Lyra", "Men": "Mensa", "Mic": "Microscopium",
        "Mon": "Monoceros", "Mus": "Musca", "Nor": "Norma", "Oct": "Octans",
        "Oph": "Ophiuchus", "Ori": "Orion", "Pav": "Pavo", "Peg": "Pegasus",
        "Per": "Perseus", "Phe": "Phoenix", "Pic": "Pictor", "Psc": "Pisces",
        "PsA": "Piscis Austrinus", "Pup": "Puppis", "Pyx": "Pyxis", "Ret": "Reticulum",
        "Sge": "Sagitta", "Sgr": "Sagittarius", "Sco": "Scorpius", "Scl": "Sculptor",
        "Sct": "Scutum", "Ser": "Serpens", "Sex": "Sextans", "Tau": "Taurus",
        "Tel": "Telescopium", "Tri": "Triangulum", "TrA": "Triangulum Australe", "Tuc": "Tucana",
        "UMa": "Ursa Major", "UMi": "Ursa Minor", "Vel": "Vela", "Vir": "Virgo",
        "Vol": "Volans", "Vul": "Vulpecula",
    ]

    static let facts: [String: ConstellationFact] = [
        "Ori": ConstellationFact(
            abbreviation: "Ori",
            westernLore: "希腊神话中的猎人俄里翁，夸口能杀尽天下野兽，被蝎子蜇死；众神把两者分置天空两侧，所以猎户与天蝎此升彼落。",
            chineseLore: "属西方白虎。腰带三星即参宿一至三，整片天区是参宿与觜宿，是二十八宿里最易辨认的一组。"
        ),
        "Sco": ConstellationFact(
            abbreviation: "Sco",
            westernLore: "蜇死俄里翁的那只蝎子。天蝎升起时猎户正好落下，古人因此把两者视为永不相见的宿敌。",
            chineseLore: "属东方青龙。含房宿、心宿与尾宿；心宿二色红，古称「大火」，用来定季节。"
        ),
        "UMa": ConstellationFact(
            abbreviation: "UMa",
            westernLore: "宙斯爱慕的少女卡利斯托被赫拉变成大熊，宙斯把她提到天上；长长的斗柄就是她的尾巴。",
            chineseLore: "北斗七星属紫微垣，是古代授时与导航的核心，「斗柄指东，天下皆春」。周边还有文昌、三台等星官。"
        ),
        "UMi": ConstellationFact(
            abbreviation: "UMi",
            westernLore: "卡利斯托之子阿卡斯，母子一同被置于天上。小熊尾端的北极星是全天最有名的指北标志。",
            chineseLore: "勾陈与北极，紫微垣的核心。勾陈一即北极星，古称「帝星」，众星拱之。"
        ),
        "Cas": ConstellationFact(
            abbreviation: "Cas",
            westernLore: "埃塞俄比亚王后卡西奥佩娅，因夸耀自己比海中仙女更美，招来海怪之祸，女儿因此被献祭。",
            chineseLore: "王良、阁道、策三组星官，属奎宿与壁宿一带，王良是古代善于驾车的人。"
        ),
        "Cyg": ConstellationFact(
            abbreviation: "Cyg",
            westernLore: "宙斯化作的天鹅，一说是歌手俄耳甫斯死后所化，因此从不鸣叫。",
            chineseLore: "天津，意为银河的渡口。天津四与河鼓二、织女一构成夏季大三角。"
        ),
        "Lyr": ConstellationFact(
            abbreviation: "Lyr",
            westernLore: "俄耳甫斯的七弦琴，琴声能感动冥王，让他带回妻子；失败后琴被置于天上。",
            chineseLore: "织女，织女一即织女星，与河鼓（牛郎）隔银河相望。"
        ),
        "Aql": ConstellationFact(
            abbreviation: "Aql",
            westernLore: "宙斯的神鹰，替宙斯衔来雷电，也奉命啄食普罗米修斯的肝脏。",
            chineseLore: "河鼓，河鼓二即牛郎星；两侧河鼓一、三常被看作牛郎担子里的两个孩子。"
        ),
        "Leo": ConstellationFact(
            abbreviation: "Leo",
            westernLore: "赫拉克勒斯十二功绩中的涅墨亚狮子，刀枪不入，最后被徒手扼死。",
            chineseLore: "轩辕与五帝座，属太微垣，是帝王与朝廷的象征；轩辕十四即狮子座最亮星。"
        ),
        "Gem": ConstellationFact(
            abbreviation: "Gem",
            westernLore: "卡斯托与波吕克斯兄弟，弟弟是神子、哥哥是凡人；哥哥死后弟弟求宙斯让两人共享不死。",
            chineseLore: "北河、南河与井宿。北河三、北河二分列黄道两侧，古人以它们的颜色判断晴雨。"
        ),
        "Tau": ConstellationFact(
            abbreviation: "Tau",
            westernLore: "宙斯化身的白牛，驮着腓尼基公主欧罗巴渡海到克里特岛。",
            chineseLore: "毕宿与昴宿，属西方白虎。昴星团即昴宿，古人以它的可见度判断视力好坏。"
        ),
        "Boo": ConstellationFact(
            abbreviation: "Boo",
            westernLore: "驱赶大熊绕北极转圈的牧人阿尔卡斯，一说他就是卡利斯托的儿子。",
            chineseLore: "大角、梗河、招摇。大角是全天第四亮星，古代以它的颜色占卜收成。"
        ),
        "Aur": ConstellationFact(
            abbreviation: "Aur",
            westernLore: "雅典王厄里克托尼俄斯，跛足却发明了四马战车，宙斯把他放进星空。",
            chineseLore: "五车，象征天子的战车与五方；五车二即御夫座最亮星。"
        ),
        "CMa": ConstellationFact(
            abbreviation: "CMa",
            westernLore: "猎户的猎犬，紧追天兔。天狼星在古埃及被用作尼罗河泛滥的预报。",
            chineseLore: "天狼、军市、弧矢。天狼星是全天最亮恒星，古称「主侵掠」，弧矢九星则象征射向它的弓。"
        ),
        "CMi": ConstellationFact(
            abbreviation: "CMi",
            westernLore: "猎户的另一只猎犬。与天狼星同升时正值盛夏，罗马人称之为「小暑星」。",
            chineseLore: "南河，与北河相对；南河三与天狼、参宿四构成冬季大三角。"
        ),
        "Cru": ConstellationFact(
            abbreviation: "Cru",
            westernLore: "16 世纪航海时代才划出的现代星座，不在古典神话中；南半球用它指向南天极。",
            chineseLore: "十字架，属近南极星官。明代《七政推步》已载「十字架星」，随郑和船队与回回历法传入。"
        ),
        "Peg": ConstellationFact(
            abbreviation: "Peg",
            westernLore: "从美杜莎血中诞生的飞马珀伽索斯，蹄击赫利孔山，踏出灵感之泉。",
            chineseLore: "室宿与壁宿，属北方玄武。秋季四边形是它最显眼的标志。"
        ),
        "And": ConstellationFact(
            abbreviation: "And",
            westernLore: "被锁在礁石上献祭给海怪的公主安德洛墨达，被珀尔修斯救下。",
            chineseLore: "奎宿与天大将军。仙女座大星系是肉眼可见的最远天体，距离约 250 万光年。"
        ),
        "Per": ConstellationFact(
            abbreviation: "Per",
            westernLore: "斩杀美杜莎的英雄珀尔修斯，手提蛇发女妖的头颅。",
            chineseLore: "天船、大陵。大陵五即英仙座 β，是著名的食变星，古人称「大陵五，其星忽明忽暗」。"
        ),
        "Sgr": ConstellationFact(
            abbreviation: "Sgr",
            westernLore: "半人马射手，拉满弓指向天蝎的心脏，是黄道十二宫中位置最南的一个。",
            chineseLore: "箕宿与斗宿，属北方玄武。银河系中心就在这个方向，古人已注意到此处「星气最密」。"
        ),
        "Vir": ConstellationFact(
            abbreviation: "Vir",
            westernLore: "正义女神阿斯特赖亚，手持丰收之角；她离开人间后，众神也随之离去。",
            chineseLore: "角宿与亢宿，属东方青龙。角宿一是二十八宿的第一宿起点，古人以它校准中星。"
        ),
        "Dra": ConstellationFact(
            abbreviation: "Dra",
            westernLore: "守护金苹果的巨龙拉冬，被赫拉克勒斯所杀；巨龙盘绕北天极。",
            chineseLore: "紫微垣的右枢、左枢与天棓。右枢是公元前 2700 年左右的北极星，因岁差而被勾陈一取代。"
        ),
        "Her": ConstellationFact(
            abbreviation: "Her",
            westernLore: "完成十二项功绩的赫拉克勒斯，单膝跪地、脚踏天龙。",
            chineseLore: "帝座，象征天帝之位，属天市垣；古代以它的颜色与亮度占卜帝王吉凶。"
        ),
        "Oph": ConstellationFact(
            abbreviation: "Oph",
            westernLore: "能起死回生的医神阿斯克勒庇俄斯，因逾越生死界限被宙斯以雷电击杀。",
            chineseLore: "天市右垣与侯，属天市垣，是天上集市的东侧围墙。"
        ),
        "Ari": ConstellationFact(
            abbreviation: "Ari",
            westernLore: "金羊毛故事中的公羊，驮着兄妹逃离祭坛，留下独角与金羊毛的传说。",
            chineseLore: "娄宿，属西方白虎；白羊座曾是春分点所在，因此黄道从它算起。"
        ),
        "Crv": ConstellationFact(
            abbreviation: "Crv",
            westernLore: "阿波罗的乌鸦，因偷懒说谎被放逐，连同水杯（巨爵）与长蛇一同被置于天上。",
            chineseLore: "轸宿，属南方朱雀；轸是车厢底部的横木，象征车驾远行。"
        ),
        "Cet": ConstellationFact(
            abbreviation: "Cet",
            westernLore: "海神派去吞噬安德洛墨达的海怪，被珀尔修斯以美杜莎之首石化。",
            chineseLore: "天囷与土司空。天囷是天上的粮仓，土司空掌管土木营造。"
        ),
        "Lib": ConstellationFact(
            abbreviation: "Lib",
            westernLore: "正义女神手中的天平，原属天蝎的双螯，罗马时代才独立成座。",
            chineseLore: "氐宿，属东方青龙；氐意为根柢，象征万物赖以生长的根基。"
        ),
        "Cap": ConstellationFact(
            abbreviation: "Cap",
            westernLore: "牧神潘跳入尼罗河躲避怪物，下半身化为鱼尾，上半身仍是羊。",
            chineseLore: "牛宿与垒壁阵。垒壁阵是环绕军营的防御工事，象征天兵的营垒。"
        ),
        "Del": ConstellationFact(
            abbreviation: "Del",
            westernLore: "把诗人阿里翁从海中救起的海豚，因善行被置于天上。",
            chineseLore: "瓠瓜，属牛宿；古人以它的明亮程度占卜年成与果菜。"
        ),
        "Cep": ConstellationFact(
            abbreviation: "Cep",
            westernLore: "安德洛墨达之父、埃塞俄比亚国王刻甫斯，因女儿之祸而束手无策。",
            chineseLore: "天钩，属紫微垣，象征天庭的钩陈与仪仗。"
        ),
    ]

    static func fact(for abbreviation: String) -> ConstellationFact? {
        facts[abbreviation]
    }

    static func region(
        for abbreviation: String,
        in stars: [Star],
        distance: Double = 0
    ) -> ConstellationRegion? {
        let members = stars.filter { $0.constellation == abbreviation }
        guard !members.isEmpty else { return nil }
        let brightest = members.min { $0.magnitude < $1.magnitude }

        var centroid = SIMD3<Double>(0, 0, 0)
        for star in members {
            let ra = star.rightAscensionHours / 24 * 2 * Double.pi
            let dec = star.declinationDegrees * Double.pi / 180
            centroid += SIMD3(cos(dec) * cos(ra), sin(dec), cos(dec) * sin(ra))
        }
        let meanRa: Double
        if simd_length(centroid) > 0.0001 {
            meanRa = atan2(centroid.z, centroid.x)
        } else {
            meanRa = 0
        }
        let raHours = (meanRa < 0 ? meanRa + 2 * Double.pi : meanRa) / (2 * Double.pi) * 24
        let index = Int((9.0 + raHours / 2).rounded()) % 12

        return ConstellationRegion(
            abbreviation: abbreviation,
            chineseName: ConstellationNames.chinese(for: abbreviation) ?? abbreviation,
            latinName: latinNames[abbreviation] ?? abbreviation,
            starCount: members.count,
            brightest: brightest,
            bestMonth: (index + 12) % 12 + 1,
            distance: distance
        )
    }

    static func nearest(to direction: SIMD3<Float>, in stars: [Star]) -> ConstellationRegion? {
        let length = simd_length(direction)
        guard length > 0.0001 else { return nil }
        let unit = direction / length

        var best: (abbreviation: String, dot: Float)?
        for star in stars {
            guard !star.constellation.isEmpty else { continue }
            let dot = simd_dot(unit, StarField.direction(
                rightAscensionHours: star.rightAscensionHours,
                declinationDegrees: star.declinationDegrees
            ))
            if best == nil || dot > best!.dot {
                best = (star.constellation, dot)
            }
        }
        guard let best else { return nil }
        let distance = acos(Double(min(max(best.dot, -1), 1))) * 180 / .pi
        return region(for: best.abbreviation, in: stars, distance: distance)
    }
}
