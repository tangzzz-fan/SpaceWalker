import Foundation
import simd

struct ConstellationFigure: Equatable, Sendable {
    var anchors: [String]
    var rings: [[SIMD2<Float>]]
}

enum ConstellationFigures {
    static let bear = ConstellationFigure(
        anchors: ["Alkaid", "Mizar", "Alioth", "Megrez", "Dubhe", "Merak", "Phecda", "Muscida", "Tania Borealis", "Tania Australis"],
        rings: [
            [
                SIMD2<Float>(-1.160, +0.780), SIMD2<Float>(-1.100, +0.960), SIMD2<Float>(-0.980, +1.080), SIMD2<Float>(-0.900, +1.100),
                SIMD2<Float>(-0.840, +1.220), SIMD2<Float>(-0.740, +1.180), SIMD2<Float>(-0.720, +1.040), SIMD2<Float>(-0.620, +0.920),
                SIMD2<Float>(-0.480, +0.880), SIMD2<Float>(-0.240, +0.840), SIMD2<Float>(+0.020, +0.800), SIMD2<Float>(+0.280, +0.720),
                SIMD2<Float>(+0.500, +0.600), SIMD2<Float>(+0.660, +0.460), SIMD2<Float>(+0.820, +0.280), SIMD2<Float>(+1.020, +0.040),
                SIMD2<Float>(+1.220, -0.200), SIMD2<Float>(+1.140, -0.340), SIMD2<Float>(+1.020, -0.260), SIMD2<Float>(+0.880, -0.100),
                SIMD2<Float>(+0.720, +0.020), SIMD2<Float>(+0.740, -0.240), SIMD2<Float>(+0.700, -0.600), SIMD2<Float>(+0.580, -0.880),
                SIMD2<Float>(+0.420, -0.960), SIMD2<Float>(+0.300, -0.900), SIMD2<Float>(+0.320, -0.700), SIMD2<Float>(+0.240, -0.560),
                SIMD2<Float>(+0.080, -0.480), SIMD2<Float>(-0.100, -0.500), SIMD2<Float>(-0.260, -0.560), SIMD2<Float>(-0.320, -0.860),
                SIMD2<Float>(-0.360, -1.140), SIMD2<Float>(-0.440, -1.280), SIMD2<Float>(-0.620, -1.300), SIMD2<Float>(-0.760, -1.240),
                SIMD2<Float>(-0.800, -1.100), SIMD2<Float>(-0.740, -0.860), SIMD2<Float>(-0.660, -0.520), SIMD2<Float>(-0.580, -0.200),
                SIMD2<Float>(-0.640, +0.140), SIMD2<Float>(-0.720, +0.460), SIMD2<Float>(-0.840, +0.600), SIMD2<Float>(-1.000, +0.640),
            ],
        ]
    )

    static let scorpion = ConstellationFigure(
        anchors: ["Dschubba", "Acrab", "Antares", "Alniyat", "Larawag", "Sargas", "Shaula", "Lesath", "Fang"],
        rings: [
            [
                SIMD2<Float>(-0.600, +0.740), SIMD2<Float>(-0.609, +0.838), SIMD2<Float>(-0.635, +0.930), SIMD2<Float>(-0.676, +1.009),
                SIMD2<Float>(-0.730, +1.069), SIMD2<Float>(-0.793, +1.107), SIMD2<Float>(-0.860, +1.120), SIMD2<Float>(-0.927, +1.107),
                SIMD2<Float>(-0.990, +1.069), SIMD2<Float>(-1.044, +1.009), SIMD2<Float>(-1.085, +0.930), SIMD2<Float>(-1.111, +0.838),
                SIMD2<Float>(-1.120, +0.740), SIMD2<Float>(-1.111, +0.642), SIMD2<Float>(-1.085, +0.550), SIMD2<Float>(-1.044, +0.471),
                SIMD2<Float>(-0.990, +0.411), SIMD2<Float>(-0.927, +0.373), SIMD2<Float>(-0.860, +0.360), SIMD2<Float>(-0.793, +0.373),
                SIMD2<Float>(-0.730, +0.411), SIMD2<Float>(-0.676, +0.471), SIMD2<Float>(-0.635, +0.550), SIMD2<Float>(-0.609, +0.642),
            ],
            [
                SIMD2<Float>(-0.780, +0.920), SIMD2<Float>(-1.080, +1.040), SIMD2<Float>(-1.020, +0.860), SIMD2<Float>(-0.840, +0.780),
            ],
            [
                SIMD2<Float>(-0.960, +0.560), SIMD2<Float>(-1.120, +0.340), SIMD2<Float>(-1.020, +0.320), SIMD2<Float>(-0.860, +0.480),
            ],
            [
                SIMD2<Float>(-0.478, +0.808), SIMD2<Float>(-0.188, +0.617), SIMD2<Float>(+0.079, +0.274), SIMD2<Float>(+0.349, -0.070),
                SIMD2<Float>(+0.633, -0.421), SIMD2<Float>(+0.887, -0.757), SIMD2<Float>(+1.000, -0.920), SIMD2<Float>(+1.101, -0.828),
                SIMD2<Float>(+1.013, -0.520), SIMD2<Float>(+1.147, -0.480), SIMD2<Float>(+1.259, -0.852), SIMD2<Float>(+1.000, -1.120),
                SIMD2<Float>(+0.713, -0.923), SIMD2<Float>(+0.407, -0.619), SIMD2<Float>(+0.091, -0.290), SIMD2<Float>(-0.199, +0.046),
                SIMD2<Float>(-0.452, +0.343), SIMD2<Float>(-0.682, +0.512),
            ],
            [
                SIMD2<Float>(+1.150, -0.500), SIMD2<Float>(+1.146, -0.474), SIMD2<Float>(+1.133, -0.450), SIMD2<Float>(+1.112, -0.429),
                SIMD2<Float>(+1.085, -0.413), SIMD2<Float>(+1.054, -0.403), SIMD2<Float>(+1.020, -0.400), SIMD2<Float>(+0.986, -0.403),
                SIMD2<Float>(+0.955, -0.413), SIMD2<Float>(+0.928, -0.429), SIMD2<Float>(+0.907, -0.450), SIMD2<Float>(+0.894, -0.474),
                SIMD2<Float>(+0.890, -0.500), SIMD2<Float>(+0.894, -0.526), SIMD2<Float>(+0.907, -0.550), SIMD2<Float>(+0.928, -0.571),
                SIMD2<Float>(+0.955, -0.587), SIMD2<Float>(+0.986, -0.597), SIMD2<Float>(+1.020, -0.600), SIMD2<Float>(+1.054, -0.597),
                SIMD2<Float>(+1.085, -0.587), SIMD2<Float>(+1.112, -0.571), SIMD2<Float>(+1.133, -0.550), SIMD2<Float>(+1.146, -0.526),
            ],
        ]
    )

    static let lion = ConstellationFigure(
        anchors: ["Regulus", "Algieba", "Adhafera", "Rasalas", "Chertan", "Zosma", "Denebola"],
        rings: [
            [
                SIMD2<Float>(-1.120, +0.840), SIMD2<Float>(-1.080, +1.020), SIMD2<Float>(-0.960, +1.120), SIMD2<Float>(-0.840, +1.180),
                SIMD2<Float>(-0.760, +1.040), SIMD2<Float>(-0.620, +0.880), SIMD2<Float>(-0.500, +0.760), SIMD2<Float>(-0.200, +0.640),
                SIMD2<Float>(+0.120, +0.520), SIMD2<Float>(+0.400, +0.380), SIMD2<Float>(+0.620, +0.180), SIMD2<Float>(+0.780, -0.020),
                SIMD2<Float>(+1.100, -0.460), SIMD2<Float>(+1.160, -0.580), SIMD2<Float>(+1.180, -0.720), SIMD2<Float>(+0.800, -0.440),
                SIMD2<Float>(+0.640, -0.500), SIMD2<Float>(+0.500, -0.700), SIMD2<Float>(+0.280, -0.680), SIMD2<Float>(+0.300, -0.360),
                SIMD2<Float>(+0.080, -0.300), SIMD2<Float>(-0.120, -0.340), SIMD2<Float>(-0.260, -0.480), SIMD2<Float>(-0.340, -0.920),
                SIMD2<Float>(-0.500, -1.080), SIMD2<Float>(-0.740, -1.120), SIMD2<Float>(-0.880, -1.000), SIMD2<Float>(-0.840, -0.720),
                SIMD2<Float>(-0.800, -0.300), SIMD2<Float>(-0.700, +0.120), SIMD2<Float>(-0.780, +0.500), SIMD2<Float>(-0.920, +0.640),
                SIMD2<Float>(-1.040, +0.660),
            ],
        ]
    )

    static let all: [String: ConstellationFigure] = [
        "UMa": bear,
        "Sco": scorpion,
        "Leo": lion,
    ]
}

/// 天上一块可判定的多边形区域：把轮廓环投影到以自身中心为法线的切平面，
/// 之后所有点都在这张平面里做多边形包含测试。星座轮廓与闭合星群共用这套判定。
struct OutlineShape: Sendable {
    /// 星座缩写或星群 id。
    var key: String
    var center: SIMD3<Float>
    var east: SIMD3<Float>
    var north: SIMD3<Float>
    var origin: SIMD2<Float>
    var half: SIMD2<Float>
    var rings: [[SIMD2<Float>]]
    /// 从中心到最远轮廓点的角距，用于粗筛。
    var radiusDegrees: Double
    /// 边界容差（归一化坐标，1 = 半个视场）。轮廓顶点本身必须算在区域内，
    /// 否则「对准轮廓上的亮星」会判成外面——射线法对边界点的归属不稳定。
    static let edgeTolerance: Float = 0.02

    func contains(_ direction: SIMD3<Float>) -> Bool {
        let vector = simd_normalize(direction)
        guard simd_dot(vector, center) >= cos(Float(radiusDegrees) * .pi / 180) else {
            return false
        }
        let degrees = SIMD2(
            asin(max(-1, min(1, simd_dot(east, vector)))) * 180 / .pi,
            asin(max(-1, min(1, simd_dot(north, vector)))) * 180 / .pi
        )
        guard abs(half.x) > 0.001, abs(half.y) > 0.001 else { return false }
        let point = SIMD2((degrees.x - origin.x) / half.x, (degrees.y - origin.y) / half.y)
        return rings.contains { ring in
            ConstellationFigureBuilder.contains(point, ring: ring)
                || ConstellationFigureBuilder.distance(point, to: ring) <= Self.edgeTolerance
        }
    }
}

enum ConstellationFigureBuilder {
    /// 用真实亮星的轮廓环构造可判定区域。环不足 3 点或退化时返回 nil。
    static func shape(
        key: String,
        rings: [[SIMD3<Float>]]
    ) -> OutlineShape? {
        let valid = rings.filter { $0.count >= 3 }.map { $0.map(simd_normalize) }
        guard !valid.isEmpty else { return nil }
        let all = valid.flatMap { $0 }
        guard all.count >= 3 else { return nil }

        var sum = SIMD3<Float>(0, 0, 0)
        for vector in all {
            sum += vector
        }
        guard simd_length(sum) > 0.001 else { return nil }
        let center = simd_normalize(sum)
        let reference = abs(center.y) < 0.99 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
        let east = simd_normalize(simd_cross(reference, center))
        let north = simd_cross(center, east)

        func project(_ vector: SIMD3<Float>) -> SIMD2<Float> {
            SIMD2(
                asin(max(-1, min(1, simd_dot(east, vector)))) * 180 / .pi,
                asin(max(-1, min(1, simd_dot(north, vector)))) * 180 / .pi
            )
        }

        let projected = valid.map { $0.map(project) }
        let xs = projected.flatMap { $0.map(\.x) }
        let ys = projected.flatMap { $0.map(\.y) }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max(),
              maxX - minX > 0.2, maxY - minY > 0.2
        else { return nil }

        let origin = SIMD2((minX + maxX) / 2, (minY + maxY) / 2)
        let half = SIMD2((maxX - minX) / 2, (maxY - minY) / 2)
        let normalized = projected.map { ring in
            ring.map { SIMD2(($0.x - origin.x) / half.x, ($0.y - origin.y) / half.y) }
        }
        let radius = all
            .map { acos(Double(min(max(simd_dot(center, $0), -1), 1))) * 180 / .pi }
            .max() ?? 0

        return OutlineShape(
            key: key,
            center: center,
            east: east,
            north: north,
            origin: origin,
            half: half,
            rings: normalized,
            radiusDegrees: radius
        )
    }

    static func rings(_ figure: ConstellationFigure, positions: [String: SIMD3<Float>]) -> [[SIMD3<Float>]] {
        guard let frame = Frame(figure: figure, positions: positions) else { return [] }
        return figure.rings
            .map { ring in ring.compactMap(frame.direction) }
            .filter { $0.count >= 3 }
    }

    static func isInside(_ name: String, figure: ConstellationFigure, positions: [String: SIMD3<Float>]) -> Bool {
        guard let frame = Frame(figure: figure, positions: positions),
              let position = positions[name],
              let point = frame.normalized(position)
        else { return false }
        return figure.rings.contains { contains(point, ring: $0) }
    }

    static func contains(_ point: SIMD2<Float>, ring: [SIMD2<Float>]) -> Bool {
        guard ring.count >= 3 else { return false }
        var inside = false
        var previous = ring.count - 1
        for index in ring.indices {
            let a = ring[index]
            let b = ring[previous]
            if (a.y > point.y) != (b.y > point.y),
               point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            previous = index
        }
        return inside
    }

    /// 点到环的最短距离。顶点与边都算，用于边界容差。
    static func distance(_ point: SIMD2<Float>, to ring: [SIMD2<Float>]) -> Float {
        guard ring.count >= 2 else { return .greatestFiniteMagnitude }
        var best = Float.greatestFiniteMagnitude
        var previous = ring.count - 1
        for index in ring.indices {
            let a = ring[previous]
            let b = ring[index]
            let ab = b - a
            let lengthSquared = simd_length_squared(ab)
            let t = lengthSquared > 1e-9
                ? max(0, min(1, simd_dot(point - a, ab) / lengthSquared))
                : 0
            best = min(best, simd_length(point - (a + ab * t)))
            previous = index
        }
        return best
    }

    struct Frame {
        var center: SIMD3<Float>
        var east: SIMD3<Float>
        var north: SIMD3<Float>
        var origin: SIMD2<Float>
        var half: SIMD2<Float>

        init?(figure: ConstellationFigure, positions: [String: SIMD3<Float>]) {
            let vectors = figure.anchors.compactMap { positions[$0] }.map(simd_normalize)
            guard vectors.count >= 2 else { return nil }
            var sum = SIMD3<Float>(0, 0, 0)
            for vector in vectors {
                sum += vector
            }
            guard simd_length(sum) > 0.001 else { return nil }
            let centerAxis = simd_normalize(sum)
            let reference = abs(centerAxis.y) < 0.99 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
            let eastAxis = simd_normalize(simd_cross(reference, centerAxis))
            let northAxis = simd_cross(centerAxis, eastAxis)
            center = centerAxis
            east = eastAxis
            north = northAxis

            let degrees = vectors.map { vector in
                SIMD2(
                    asin(max(-1, min(1, simd_dot(eastAxis, vector)))) * 180 / .pi,
                    asin(max(-1, min(1, simd_dot(northAxis, vector)))) * 180 / .pi
                )
            }
            let xs = degrees.map(\.x)
            let ys = degrees.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(),
                  let minY = ys.min(), let maxY = ys.max(),
                  maxX - minX > 0.5, maxY - minY > 0.5
            else { return nil }
            origin = SIMD2((minX + maxX) / 2, (minY + maxY) / 2)
            half = SIMD2((maxX - minX) / 2, (maxY - minY) / 2)
        }

        func direction(_ normalized: SIMD2<Float>) -> SIMD3<Float>? {
            let degrees = SIMD2(
                origin.x + normalized.x * half.x,
                origin.y + normalized.y * half.y
            )
            let angle = simd_length(degrees) * .pi / 180
            guard angle > 0.000001 else { return center }
            let tangentVector = east * degrees.x + north * degrees.y
            guard simd_length(tangentVector) > 0.000001 else { return center }
            let tangent = simd_normalize(tangentVector)
            return simd_normalize(center * cos(angle) + tangent * sin(angle))
        }

        func normalized(_ position: SIMD3<Float>) -> SIMD2<Float>? {
            let degrees = local(simd_normalize(position))
            guard abs(half.x) > 0.001, abs(half.y) > 0.001 else { return nil }
            return SIMD2((degrees.x - origin.x) / half.x, (degrees.y - origin.y) / half.y)
        }

        private func local(_ vector: SIMD3<Float>) -> SIMD2<Float> {
            SIMD2(
                asin(max(-1, min(1, simd_dot(east, vector)))) * 180 / .pi,
                asin(max(-1, min(1, simd_dot(north, vector)))) * 180 / .pi
            )
        }
    }
}
