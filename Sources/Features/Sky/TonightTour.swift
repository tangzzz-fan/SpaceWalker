import Foundation

struct TonightStop: Identifiable, Equatable, Sendable {
    var pick: TonightPick
    var tip: String
    var order: Int

    var id: String {
        "\(order).\(pick.id)"
    }
}

struct TonightTour: Identifiable, Equatable, Sendable {
    var headline: String
    var stops: [TonightStop]

    var id: String {
        headline
    }

    static func build(picks: [TonightPick], date: Date, limit: Int = 4) -> TonightTour? {
        guard let first = picks.first else { return nil }
        let chosen = Array(picks.prefix(limit))
        let stops = chosen.enumerated().map { index, pick in
            TonightStop(pick: pick, tip: SkyTips.tip(for: pick.group.title), order: index + 1)
        }
        return TonightTour(headline: headline(for: first, date: date), stops: stops)
    }

    static func headline(for pick: TonightPick, date: Date) -> String {
        "\(timeText(date))，\(pick.group.title)\(placement(pick))，是此刻最值得抬头看的一个。"
    }

    static func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return "此刻 \(formatter.string(from: date))"
    }

    static func placement(_ pick: TonightPick) -> String {
        let direction = SkySeason.directionLabel(azimuth: pick.azimuth)
        let altitude = Int(pick.altitude.rounded())
        switch pick.altitude {
        case 70...:
            return "几乎就在头顶"
        case 45..<70:
            return "高悬在\(direction)方"
        case 20..<45:
            return "挂在\(direction)方约 \(altitude)° 高"
        default:
            return "刚爬上\(direction)方低空"
        }
    }
}

enum SkyTips {
    static func tip(for title: String) -> String {
        tips[title] ?? "把手机转向它的方位，先锁定里面最亮的那颗。"
    }

    static let tips: [String: String] = [
        "大熊座": "北斗七星：斗柄的弧线延长出去指向牧夫的大角，斗口两颗朝北极星。",
        "小熊座": "北极星在斗柄末端，整夜几乎不动，其余六颗绕着它转。",
        "猎户座": "腰带三星几乎等距排成一线，是全天最好认的标记；左肩参宿四发红，右下参宿七最亮。",
        "仙后座": "五颗亮星连成 W，和大熊隔着北极星遥遥相对，找北极星的好帮手。",
        "天鹅座": "十字形沿银河展开，天津四是十字顶端最亮那颗，十字底部是辇道增七。",
        "天琴座": "织女星旁边四颗暗星围成一个小平行四边形，很小但很干净。",
        "天鹰座": "牛郎星两侧各一颗暗星，三颗几乎等距连成一线，就是「扁担」。",
        "天蝎座": "心宿二明显发红，尾巴向南勾起一串星，像真的蝎尾。",
        "狮子座": "头部像反写的问号（镰刀），轩辕十四就在镰刀柄的底部。",
        "双子座": "北河二与北河三并肩，下面两串暗星拉出两条腿。",
        "金牛座": "V 形牛脸，毕宿五橙红；一侧肩膀上是一小团昴星团，眼神不好也能看见。",
        "牧夫座": "大角星很亮，整个星座像风筝；顺着北斗斗柄的弧线延长就能找到。",
        "御夫座": "五边形，五车二发黄；它跑到头顶附近时最好认。",
        "大犬座": "天狼星全天最亮，低空时闪得厉害，旁边几颗凑成狗身。",
        "小犬座": "南河三和天狼、参宿四组成冬季大三角，它是最小的那个角。",
        "南十字座": "四颗星成十字，长轴指向南天极；北半球大部分地区看不到。",
        "飞马座": "秋季四边形：四颗二等星围成一个大方块，几乎空无一物，反而好认。",
        "仙女座": "三颗星连成一线，从壁宿二往东北数是 M31 的方向，肉眼是一小团雾。",
        "英仙座": "天船三周围散成弧形，旁边有一对双星团，望远镜里的常客。",
        "人马座": "茶壶形状，壶嘴正对银河中心，夏季银河最亮的一段在这儿。",
        "室女座": "角宿一发白，顺着大熊斗柄的弧线继续延长过去就是它。",
        "天龙座": "在小熊与大熊之间绕一圈，龙头是四颗星组成的小四边形。",
        "武仙座": "四颗星组成「拱心石」，两边各伸出一串暗星当腿。",
        "蛇夫座": "巨大但偏暗，主体是个细长的五边形，跨在银河上。",
        "白羊座": "三颗星组成一个钝角小三角，娄宿三最亮，秋天在东方。",
        "乌鸦座": "四颗星组成一个小四边形，就在室女座西南边。",
        "鲸鱼座": "头部是个五边形，最亮的 Menkar 发橙；身子一路向东南拖很长。",
        "天秤座": "两颗主星像扁担的两头，中间一段很空。",
        "摩羯座": "倒三角，整体偏暗，得靠附近的人马座定位。",
        "海豚座": "四颗星组成一个小菱形，像一只跃出水面的海豚，很小但形状利落。",
        "仙王座": "五颗星组成尖顶房子，就在仙后座北侧，中间那段像屋脊。",
    ]
}
