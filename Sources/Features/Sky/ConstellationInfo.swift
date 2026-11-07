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

/// 点环（或顶栏）落在天上一块有名字的区域。星座与星群走同一套判定，
/// 但两者的「来头」不是同一种东西，所以答案要能分清是哪一类。
enum SkyRegion: Equatable, Sendable {
    case constellation(ConstellationRegion)
    case pattern(SkyPattern)

    var key: String {
        switch self {
        case .constellation(let region): region.abbreviation
        case .pattern(let pattern): pattern.id
        }
    }

    var title: String {
        switch self {
        case .constellation(let region): region.chineseName
        case .pattern(let pattern): pattern.name
        }
    }

    /// 轮廓判定命中时距离为 0；兜底的最近星判定才有真实角距。
    var distance: Double {
        switch self {
        case .constellation(let region): region.distance
        case .pattern: 0
        }
    }
}

enum ConstellationInfo {
    /// 全天任意方向到「有星座归属的成员星」的最大角距，实测值。
    /// 6 等星表把整个天球盖满（p50 1.8°、p99 4.9°、最远 6.9°），
    /// 所以顶栏兜底不需要再加角距门槛——加了也永远不会触发。
    static let worstNearestStarDegrees: Double = 6.9

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
        "Ant": ConstellationFact(
            abbreviation: "Ant",
            westernLore: "1750 年代由拉卡伊在南天划出，纪念物理学家波义耳的气泵。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Aps": ConstellationFact(
            abbreviation: "Aps",
            westernLore: "1598 年荷兰航海者凯泽与德豪特曼所设，原名「天堂鸟」，后改称天燕。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Aqr": ConstellationFact(
            abbreviation: "Aqr",
            westernLore: "特洛伊王子伽倪墨得斯被宙斯化作的鹰叼上奥林匹斯，成为众神的斟酒人。",
            chineseLore: "跨女宿、虚宿、危宿。危宿一与虚宿一分别是它的 α、β 星；「羽林军」「坟墓」都在这一带。"
        ),
        "Ara": ConstellationFact(
            abbreviation: "Ara",
            westernLore: "众神与泰坦开战之前，在此坛上焚香立誓结盟，之后这祭坛被放到天上。",
            chineseLore: "属尾宿、箕宿，位置偏南，中国大部分地区只能看到坛口。"
        ),
        "Cae": ConstellationFact(
            abbreviation: "Cae",
            westernLore: "拉卡伊设，取雕刻家手中的凿子，用来纪念这门手艺。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Cam": ConstellationFact(
            abbreviation: "Cam",
            westernLore: "1612 年普朗修斯所设。原想纪念《圣经》中驮着利百加的长颈兽，因经上没写名字，索性叫它长颈鹿。",
            chineseLore: "属紫微垣北缘，「六甲」「天棓」一带延伸到这片空区。"
        ),
        "Car": ConstellationFact(
            abbreviation: "Car",
            westernLore: "南船座阿尔戈号的龙骨——伊阿宋率众英雄远航取金羊毛的那条船。",
            chineseLore: "属鬼宿。船底座 α 即老人星，全天第二亮，中国称「南极老人」，主寿，只在南方低空露面。"
        ),
        "Cen": ConstellationFact(
            abbreviation: "Cen",
            westernLore: "半人马喀戎，阿喀琉斯与伊阿宋的老师，也是医神的师父。",
            chineseLore: "跨角宿、亢宿、氐宿。南门二与马腹一并称「南门」，古人靠它们定南方。"
        ),
        "Cha": ConstellationFact(
            abbreviation: "Cha",
            westernLore: "1598 年荷兰航海者所设，南天的小星座。",
            chineseLore: "南天深处，中国传统星表在此基本没有命名星官。"
        ),
        "Cir": ConstellationFact(
            abbreviation: "Cir",
            westernLore: "拉卡伊设，取绘图用的圆规，代表他绘制南天星图时用的工具。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Cnc": ConstellationFact(
            abbreviation: "Cnc",
            westernLore: "赫拉克勒斯与九头蛇缠斗时踩到的那只螃蟹，赫拉把它升上天空作为奖赏。",
            chineseLore: "鬼宿所在。中央那团模糊的蜂巢星团就是「积尸气」，古人视为丧葬之兆。"
        ),
        "Col": ConstellationFact(
            abbreviation: "Col",
            westernLore: "诺亚方舟放出去探陆地的那只鸽子，衔回橄榄枝报平安。",
            chineseLore: "属参宿、井宿，含「丈人」「子」「孙」等星官。"
        ),
        "Com": ConstellationFact(
            abbreviation: "Com",
            westernLore: "埃及王后贝勒尼基二世剪下头发献给阿佛洛狄忒，头发被放到天上成了这片暗星。",
            chineseLore: "属太微垣，含「郎将」「周鼎」等星官。"
        ),
        "CrA": ConstellationFact(
            abbreviation: "CrA",
            westernLore: "人马手中弓箭旁的一顶冠冕，被单独放到南天。",
            chineseLore: "属箕宿，含「鳖」星官，中国大部分地区看不到。"
        ),
        "CrB": ConstellationFact(
            abbreviation: "CrB",
            westernLore: "忒修斯带回的阿里阿德涅婚冠，被狄俄尼索斯抛上天空。",
            chineseLore: "属天市垣，含「贯索」，古人视之为牢狱，以它的明暗占卜刑狱。"
        ),
        "Crt": ConstellationFact(
            abbreviation: "Crt",
            westernLore: "阿波罗的酒杯。乌鸦替阿波罗取水时延误，谎称被水蛇拦住，连杯带蛇一起被扔上天。",
            chineseLore: "属翼宿，含「天相」星官，杯身在南天低处。"
        ),
        "CVn": ConstellationFact(
            abbreviation: "CVn",
            westernLore: "牧夫牵着的两只猎犬，跟着大熊绕北极星转，最亮的一颗叫常陈一。",
            chineseLore: "属太微垣，含「常陈」，主宿卫，是天子近旁的禁军。"
        ),
        "Dor": ConstellationFact(
            abbreviation: "Dor",
            westernLore: "1598 年荷兰航海者所设，原名「剑鱼」。",
            chineseLore: "南天深空，大麦哲伦云的一部分落在它的范围里。"
        ),
        "Equ": ConstellationFact(
            abbreviation: "Equ",
            westernLore: "与飞马珀伽索斯有关的幼马；一说半人马喀戎之女希佩所化。",
            chineseLore: "属虚宿、危宿，是全天第二小的星座。"
        ),
        "Eri": ConstellationFact(
            abbreviation: "Eri",
            westernLore: "法厄同驾驭太阳车失控，被宙斯击落，坠入的这条河。",
            chineseLore: "南北跨度极大，跨参宿、井宿、娄宿、昴宿，含「天园」「九州殊口」。"
        ),
        "For": ConstellationFact(
            abbreviation: "For",
            westernLore: "拉卡伊设，纪念化学家做实验用的熔炉，那里只有几颗暗星。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Gru": ConstellationFact(
            abbreviation: "Gru",
            westernLore: "1598 年荷兰航海者所设，最初画的是火烈鸟。",
            chineseLore: "属斗宿、箕宿，位置偏南，中国南方才能看全。"
        ),
        "Hor": ConstellationFact(
            abbreviation: "Hor",
            westernLore: "拉卡伊设，取摆钟，用来纪念航海计时器的发明。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Hya": ConstellationFact(
            abbreviation: "Hya",
            westernLore: "被赫拉克勒斯斩杀的九头蛇，赫拉把它放到天上。",
            chineseLore: "横跨柳宿、星宿、张宿、翼宿，是全天最长的一个星座。"
        ),
        "Hyi": ConstellationFact(
            abbreviation: "Hyi",
            westernLore: "1598 年荷兰航海者所设，南天的一条水蛇。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Ind": ConstellationFact(
            abbreviation: "Ind",
            westernLore: "1598 年荷兰航海者所设，代表他们沿途见到的美洲原住民。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Lac": ConstellationFact(
            abbreviation: "Lac",
            westernLore: "1690 年海维留斯所设。周围星太暗，他说「得眯着眼像蝎虎一样才找得到」。",
            chineseLore: "属危宿、室宿，星都很暗，得靠仙后座引路。"
        ),
        "Lep": ConstellationFact(
            abbreviation: "Lep",
            westernLore: "猎户脚边的一只野兔，正被猎户牵着的大犬追赶。",
            chineseLore: "属参宿、井宿，含「厕」「屏」，都是些小星官。"
        ),
        "LMi": ConstellationFact(
            abbreviation: "LMi",
            westernLore: "海维留斯从大熊座身上划出来的一块，给大熊添了只小狮子。",
            chineseLore: "属太微垣，落在「常陈」与「轩辕」之间的暗区。"
        ),
        "Lup": ConstellationFact(
            abbreviation: "Lup",
            westernLore: "半人马扛着的祭品，后来被画成一头狼，蹲在南天低处。",
            chineseLore: "属氐宿、房宿，半人马扛着它，南天低处可见。"
        ),
        "Lyn": ConstellationFact(
            abbreviation: "Lyn",
            westernLore: "海维留斯所设，说「要有猞猁的眼力才看得清这里的星」。",
            chineseLore: "属井宿，全是四五等以下的暗星，得靠周边亮星定位。"
        ),
        "Men": ConstellationFact(
            abbreviation: "Men",
            westernLore: "拉卡伊设，纪念南非开普敦的桌山——他当年就在那里观测。",
            chineseLore: "南天深处，中国传统星表在此基本没有命名星官。"
        ),
        "Mic": ConstellationFact(
            abbreviation: "Mic",
            westernLore: "拉卡伊设，取显微镜，纪念这门新兴的观察手艺。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Mon": ConstellationFact(
            abbreviation: "Mon",
            westernLore: "1612 年普朗修斯所设的独角兽，正好落在银河里。",
            chineseLore: "属井宿、鬼宿，含「四渎」「阙丘」。"
        ),
        "Mus": ConstellationFact(
            abbreviation: "Mus",
            westernLore: "1598 年荷兰航海者所设，最初叫「蜜蜂」。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Nor": ConstellationFact(
            abbreviation: "Nor",
            westernLore: "拉卡伊设，取木工用的曲尺，与三角板、直尺成套。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Oct": ConstellationFact(
            abbreviation: "Oct",
            westernLore: "拉卡伊设，南天极就在这个星座里，但那里没有亮星。",
            chineseLore: "南天深处，中国传统星表在此基本没有命名星官。"
        ),
        "Pav": ConstellationFact(
            abbreviation: "Pav",
            westernLore: "1598 年荷兰航海者所设，取他们一路上见到的孔雀。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Phe": ConstellationFact(
            abbreviation: "Phe",
            westernLore: "1598 年荷兰航海者所设的凤凰，从灰烬里重生。",
            chineseLore: "属翼宿、轸宿边缘，南天低处，中国大部分地区看不到。"
        ),
        "Pic": ConstellationFact(
            abbreviation: "Pic",
            westernLore: "拉卡伊设，取画架，纪念画家作画时用的支架。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Psc": ConstellationFact(
            abbreviation: "Psc",
            westernLore: "阿佛洛狄忒与厄洛斯化作两条鱼逃离堤丰，用绳子系住尾巴，免得走散。",
            chineseLore: "属奎宿、娄宿，含「外屏」「天溷」。"
        ),
        "PsA": ConstellationFact(
            abbreviation: "PsA",
            westernLore: "与双鱼同源，一说为河神俄刻阿诺斯之鱼，口中吐水。",
            chineseLore: "属牛宿。北落师门是它的 α 星，古人以它上中天定秋分。"
        ),
        "Pup": ConstellationFact(
            abbreviation: "Pup",
            westernLore: "南船座的船尾，整条阿尔戈号被拆成三块后留下的最后一段。",
            chineseLore: "属井宿、鬼宿，含「弧矢」与老人星一带。"
        ),
        "Pyx": ConstellationFact(
            abbreviation: "Pyx",
            westernLore: "拉卡伊设，最初叫「罗盘座」，后改为水手用的磁罗盘。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Ret": ConstellationFact(
            abbreviation: "Ret",
            westernLore: "拉卡伊设，取光学仪器里用来瞄准的十字线网。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Scl": ConstellationFact(
            abbreviation: "Scl",
            westernLore: "拉卡伊设，取雕刻家的工作室，那片天区极空。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Sct": ConstellationFact(
            abbreviation: "Sct",
            westernLore: "1690 年海维留斯所设，纪念波兰国王索别斯基在维也纳之战中的盾。",
            chineseLore: "属斗宿、箕宿，紧贴银河最亮的一段。"
        ),
        "Ser": ConstellationFact(
            abbreviation: "Ser",
            westernLore: "医神阿斯克勒庇俄斯手中那条蛇，传说他靠蛇衔来的草救活死人。",
            chineseLore: "被蛇夫座分成头尾两段，属天市垣。"
        ),
        "Sex": ConstellationFact(
            abbreviation: "Sex",
            westernLore: "海维留斯设，取他用来测量星与星角距的六分仪。",
            chineseLore: "属星宿、柳宿，只有几颗四等星，形状像一条短线。"
        ),
        "Sge": ConstellationFact(
            abbreviation: "Sge",
            westernLore: "赫拉克勒斯射杀啄食普罗米修斯肝脏那只鹰的箭。",
            chineseLore: "属女宿、虚宿，很小，形如一枝箭。"
        ),
        "Tel": ConstellationFact(
            abbreviation: "Tel",
            westernLore: "拉卡伊设，取望远镜，纪念他那个时代最新的观测工具。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "TrA": ConstellationFact(
            abbreviation: "TrA",
            westernLore: "1598 年荷兰航海者所设，南天的三角形。",
            chineseLore: "属翼宿、轸宿边缘，南天低处，三颗亮星成三角。"
        ),
        "Tri": ConstellationFact(
            abbreviation: "Tri",
            westernLore: "希腊字母 Δ，被认作尼罗河三角洲或西西里岛。",
            chineseLore: "属娄宿、胃宿，三颗星大小相近，很早就被单独列出。"
        ),
        "Tuc": ConstellationFact(
            abbreviation: "Tuc",
            westernLore: "1598 年荷兰航海者所设，原名「印度鸬鹚」。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Vel": ConstellationFact(
            abbreviation: "Vel",
            westernLore: "南船座的船帆，整条阿尔戈号拆成三块后留下的帆。",
            chineseLore: "属鬼宿、翼宿，含「天社」，是南船座里最靠北的一段。"
        ),
        "Vol": ConstellationFact(
            abbreviation: "Vol",
            westernLore: "1598 年荷兰航海者所设的飞鱼，在船底座以南。",
            chineseLore: "南天深空，中国传统星表在此基本没有命名星官。"
        ),
        "Vul": ConstellationFact(
            abbreviation: "Vul",
            westernLore: "海维留斯所设，原本画的是「狐狸叼着一只鹅」。",
            chineseLore: "属牛宿、女宿，只有一颗四等星，其余都很暗。"
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
