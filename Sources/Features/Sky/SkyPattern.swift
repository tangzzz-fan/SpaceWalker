import Foundation
import simd

/// 星群：跨星座的亮星连线，教用户「先认大形状，再认小星座」。
///
/// 与「星官」不是一回事：星官是中国古代星官体系的成员，星群是近代西方认星习惯里的路标
/// （冬季大三角、夏季大三角、春季大弧线）。两者可以共用同一片天区，但语义各自独立。
struct SkyPattern: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var latin: String
    var anchors: [String]
    /// 首尾相连成面（三角形）或留作折线（弧线）。只有闭合的星群才有可判定的内部。
    var closed: Bool
    var summary: String
    var season: String

    var starCount: Int {
        Set(anchors).count
    }
}

enum SkyPatternCatalog {
    static let all: [SkyPattern] = [
        SkyPattern(
            id: "winter-triangle",
            name: "冬季大三角",
            latin: "Winter Triangle",
            anchors: ["Sirius", "Procyon", "Betelgeuse"],
            closed: true,
            summary: "天狼、南河三、参宿四，三颗一等星围出一个近乎等边的三角形。冬夜先找它，大犬、小犬、猎户就一并到手。",
            season: "十二月至二月前半夜"
        ),
        SkyPattern(
            id: "summer-triangle",
            name: "夏季大三角",
            latin: "Summer Triangle",
            anchors: ["Vega", "Deneb", "Altair"],
            closed: true,
            summary: "织女、天津四、牛郎横跨天琴、天鹅、天鹰三个星座。夏夜光害再重，这三颗也压得住。",
            season: "六月至九月前半夜"
        ),
        SkyPattern(
            id: "spring-arc",
            name: "春季大弧线",
            latin: "Spring Arc",
            anchors: ["Alioth", "Mizar", "Alkaid", "Arcturus", "Spica"],
            closed: false,
            summary: "顺着北斗斗柄的弧线延长，先撞上大角，再撞上角宿一。「顺柄找弧，弧到角宿」，春季定位最省力的一条路。",
            season: "三月至五月前半夜"
        ),
    ]

    static func pattern(id: String) -> SkyPattern? {
        all.first { $0.id == id }
    }
}

enum SkyPatternGeometry {
    /// 虚线段长（度）。1.3° 大约是一臂远处两根手指的宽度，看得见又不至于连成实线。
    static let dashDegrees: Double = 1.3
    /// 空隙占周期的比例。虚线是为了和星座连线区分：星座连线是实线，星群是参考线。
    static let gapRatio: Double = 0.45
    /// 每段两端各让出的角距。最亮的星（视星等 -1.5）视半径约 0.71°，
    /// 让出 1° 后虚线不会插进星点里——星群是参考线，不是星座的骨架。
    static let anchorInsetDegrees: Double = 1.0

    /// 大圆插值：沿 A→B 的弧走 fraction（0…1）。
    static func slerp(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        fraction: Double
    ) -> SIMD3<Float> {
        let first = simd_normalize(start)
        let second = simd_normalize(end)
        let angle = acos(Double(min(max(simd_dot(first, second), -1), 1)))
        let sine = sin(angle)
        guard abs(sine) > 0.000001 else { return first }
        let left = sin((1 - fraction) * angle) / sine
        let right = sin(fraction * angle) / sine
        return simd_normalize(first * Float(left) + second * Float(right))
    }

    static func angleDegrees(_ first: SIMD3<Float>, _ second: SIMD3<Float>) -> Double {
        acos(Double(min(max(simd_dot(simd_normalize(first), simd_normalize(second)), -1), 1)))
            * 180 / .pi
    }

    /// 把一条大圆弧切成等角距的短段，段与段之间留空。
    static func dashes(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        dashDegrees: Double = SkyPatternGeometry.dashDegrees,
        gapRatio: Double = SkyPatternGeometry.gapRatio
    ) -> [(SIMD3<Float>, SIMD3<Float>)] {
        let first = simd_normalize(start)
        let second = simd_normalize(end)
        let angle = acos(Double(min(max(simd_dot(first, second), -1), 1)))
        let degrees = angle * 180 / .pi
        guard degrees > 0.05, gapRatio > 0, gapRatio < 0.9, dashDegrees > 0 else { return [] }

        let period = dashDegrees / (1 - gapRatio)
        let count = max(2, Int((degrees / period).rounded()))
        let step = angle / Double(count)
        let dashAngle = step * (1 - gapRatio)

        var result: [(SIMD3<Float>, SIMD3<Float>)] = []
        for index in 0..<count {
            let start = Double(index) * step
            result.append((
                slerp(from: first, to: second, fraction: start / angle),
                slerp(from: first, to: second, fraction: (start + dashAngle) / angle)
            ))
        }
        return result
    }

    /// 闭合星群的多边形环；折线星群返回 nil（没有内部，不参与「落在星群里」判定）。
    static func ring(for pattern: SkyPattern, positions: [String: SIMD3<Float>]) -> [SIMD3<Float>]? {
        guard pattern.closed else { return nil }
        let points = pattern.anchors.compactMap { positions[$0] }
        guard points.count == pattern.anchors.count, points.count >= 3 else { return nil }
        return points
    }

    /// 一条星群的全部虚线段，已经缩放到指定天球半径。
    static func segments(
        for pattern: SkyPattern,
        positions: [String: SIMD3<Float>],
        radius: Float
    ) -> [(SIMD3<Float>, SIMD3<Float>)] {
        let points = pattern.anchors.compactMap { positions[$0] }
        guard points.count == pattern.anchors.count, points.count >= 2 else { return [] }

        var pairs: [(SIMD3<Float>, SIMD3<Float>)] = []
        for index in 0..<(points.count - 1) {
            pairs.append((points[index], points[index + 1]))
        }
        if pattern.closed, let last = points.last, let first = points.first {
            pairs.append((last, first))
        }

        return pairs.flatMap { pair -> [(SIMD3<Float>, SIMD3<Float>)] in
            let edge = angleDegrees(pair.0, pair.1)
            guard edge > anchorInsetDegrees * 2.4 else { return [] }
            let inset = anchorInsetDegrees / edge
            let start = slerp(from: pair.0, to: pair.1, fraction: inset)
            let end = slerp(from: pair.0, to: pair.1, fraction: 1 - inset)
            return dashes(from: start, to: end).map { dash in
                (simd_normalize(dash.0) * radius, simd_normalize(dash.1) * radius)
            }
        }
    }
}
