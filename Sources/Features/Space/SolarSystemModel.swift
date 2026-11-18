import Foundation
import simd

enum BodyKind: String, Equatable, Sendable {
    case star
    case planet
}

enum BodyID: String, CaseIterable, Equatable, Sendable {
    case sun
    case mercury
    case venus
    case earth
    case mars
    case jupiter
    case saturn
    case uranus
    case neptune

    var isPlanet: Bool {
        self != .sun
    }
}

struct SolarBody: Equatable, Sendable {
    let id: BodyID
    let name: String
    let latinName: String
    let kind: BodyKind
    let diameterKilometers: Double
    let semiMajorAxisAU: Double
    let orbitalPeriodDays: Double
    let colorHex: UInt32
    let blurb: String

    var hasRing: Bool {
        id == .saturn
    }
}

enum SolarSystem {
    static let bodies: [SolarBody] = [
        SolarBody(
            id: .sun,
            name: "太阳",
            latinName: "Sol",
            kind: .star,
            diameterKilometers: 1_392_700,
            semiMajorAxisAU: 0,
            orbitalPeriodDays: 0,
            colorHex: 0xFFB347,
            blurb: "太阳系唯一的恒星，质量占整个太阳系的 99.86%。"
        ),
        SolarBody(
            id: .mercury,
            name: "水星",
            latinName: "Mercury",
            kind: .planet,
            diameterKilometers: 4_879,
            semiMajorAxisAU: 0.387,
            orbitalPeriodDays: 87.97,
            colorHex: 0x9C8C82,
            blurb: "离太阳最近，公转只需 88 天，表面昼夜温差超过 600°C。"
        ),
        SolarBody(
            id: .venus,
            name: "金星",
            latinName: "Venus",
            kind: .planet,
            diameterKilometers: 12_104,
            semiMajorAxisAU: 0.723,
            orbitalPeriodDays: 224.70,
            colorHex: 0xE6C79B,
            blurb: "被浓密二氧化碳包裹，表面约 465°C，比水星更热。"
        ),
        SolarBody(
            id: .earth,
            name: "地球",
            latinName: "Earth",
            kind: .planet,
            diameterKilometers: 12_756,
            semiMajorAxisAU: 1.0,
            orbitalPeriodDays: 365.26,
            colorHex: 0x3E7BD6,
            blurb: "已知唯一存在生命的行星，71% 表面被液态水覆盖。"
        ),
        SolarBody(
            id: .mars,
            name: "火星",
            latinName: "Mars",
            kind: .planet,
            diameterKilometers: 6_792,
            semiMajorAxisAU: 1.524,
            orbitalPeriodDays: 686.98,
            colorHex: 0xC1552F,
            blurb: "拥有太阳系最高的火山奥林帕斯山，高约 22 公里。"
        ),
        SolarBody(
            id: .jupiter,
            name: "木星",
            latinName: "Jupiter",
            kind: .planet,
            diameterKilometers: 142_984,
            semiMajorAxisAU: 5.203,
            orbitalPeriodDays: 4_332.59,
            colorHex: 0xD3A16A,
            blurb: "质量是其余行星总和的 2.5 倍，大红斑是持续数百年的风暴。"
        ),
        SolarBody(
            id: .saturn,
            name: "土星",
            latinName: "Saturn",
            kind: .planet,
            diameterKilometers: 120_536,
            semiMajorAxisAU: 9.537,
            orbitalPeriodDays: 10_759.22,
            colorHex: 0xF0D9A0,
            blurb: "环主要由冰与岩石碎块组成，厚度平均不足 100 米。"
        ),
        SolarBody(
            id: .uranus,
            name: "天王星",
            latinName: "Uranus",
            kind: .planet,
            diameterKilometers: 51_118,
            semiMajorAxisAU: 19.19,
            orbitalPeriodDays: 30_688.5,
            colorHex: 0x8FD3D8,
            blurb: "自转轴几乎躺倒在轨道面上，倾角约 98°。"
        ),
        SolarBody(
            id: .neptune,
            name: "海王星",
            latinName: "Neptune",
            kind: .planet,
            diameterKilometers: 49_528,
            semiMajorAxisAU: 30.07,
            orbitalPeriodDays: 60_182,
            colorHex: 0x4C6FD6,
            blurb: "风速可达 2100 km/h，是太阳系风暴最猛烈的行星。"
        ),
    ]

    static let byID: [BodyID: SolarBody] = Dictionary(
        uniqueKeysWithValues: bodies.map { ($0.id, $0) }
    )

    static func body(_ id: BodyID) -> SolarBody? {
        byID[id]
    }

    static var planets: [SolarBody] {
        bodies.filter { $0.kind == .planet }
    }
}

enum SolarLayout {
    static let orbitExponent: Double = 0.42
    static let orbitUnit: Float = 1.0
    static let radiusExponent: Double = 0.30
    static let earthDiameterKilometers: Double = 12_756
    static let earthDisplayRadius: Float = 0.08
    static let sunDisplayRadiusCap: Float = 0.30
    static let orbitLineRadius: Float = 0.0028

    static func orbitRadius(for body: SolarBody) -> Float {
        guard body.semiMajorAxisAU > 0 else { return 0 }
        return Float(pow(body.semiMajorAxisAU, orbitExponent)) * orbitUnit
    }

    static func bodyRadius(for body: SolarBody) -> Float {
        let scaled = Float(pow(body.diameterKilometers / earthDiameterKilometers, radiusExponent))
            * earthDisplayRadius
        return min(scaled, sunDisplayRadiusCap)
    }

    static func heliocentricLongitude(body: BodyID, julianDay: Double) -> Double? {
        guard let body = SolarSystem.body(body), body.semiMajorAxisAU > 0,
              let vector = Ephemeris.heliocentricEcliptic(
                  of: ephemerisBody(body.id), julianDay: julianDay
              )
        else { return nil }
        var longitude = atan2(vector.y, vector.x)
        if longitude < 0 { longitude += 2 * .pi }
        return longitude
    }

    static func position(for body: SolarBody, julianDay: Double) -> SIMD3<Float> {
        let radius = orbitRadius(for: body)
        guard radius > 0,
              let theta = heliocentricLongitude(body: body.id, julianDay: julianDay)
        else { return .zero }
        return SIMD3(cos(Float(theta)) * radius, 0, sin(Float(theta)) * radius)
    }

    static func ephemerisBody(_ id: BodyID) -> EphemerisBody {
        switch id {
        case .sun: .sun
        case .mercury: .mercury
        case .venus: .venus
        case .earth: .earth
        case .mars: .mars
        case .jupiter: .jupiter
        case .saturn: .saturn
        case .uranus: .uranus
        case .neptune: .neptune
        }
    }

    static func lightTravelText(for body: SolarBody, julianDay: Double) -> String? {
        guard body.semiMajorAxisAU > 0,
              let vector = Ephemeris.heliocentricEcliptic(
                  of: ephemerisBody(body.id), julianDay: julianDay
              )
        else { return nil }
        let distanceAU = (vector.x * vector.x + vector.y * vector.y + vector.z * vector.z).squareRoot()
        let seconds = Ephemeris.lightTravelSeconds(distanceAU: distanceAU)
        if seconds < 90 {
            return String(format: "光从太阳到这里需要 %.0f 秒", seconds)
        }
        if seconds < 5400 {
            return String(format: "光从太阳到这里需要 %.1f 分钟", seconds / 60)
        }
        return String(format: "光从太阳到这里需要 %.1f 小时", seconds / 3600)
    }
}
