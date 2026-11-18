import Foundation

enum EphemerisBody: String, CaseIterable, Equatable, Hashable, Sendable {
    case mercury, venus, earth, mars, jupiter, saturn, uranus, neptune, sun, moon

    var isPlanet: Bool {
        switch self {
        case .sun, .moon, .earth: false
        default: true
        }
    }
}

struct EquatorialCoordinate: Equatable, Sendable {
    var raHours: Double
    var decDegrees: Double

    var raDegrees: Double { raHours * 15 }
}

enum Ephemeris {
    static let j2000: Double = 2_451_545.0
    static let auKilometers: Double = 149_597_870.7
    static let lightSpeedKilometersPerSecond: Double = 299_792.458

    static func julianDay(utc date: Date) -> Double {
        date.timeIntervalSince1970 / 86400 + 2_440_587.5
    }

    static func equatorial(of body: EphemerisBody, julianDay jd: Double) -> EquatorialCoordinate? {
        switch body {
        case .earth:
            return nil
        case .moon:
            return Moon.equatorial(julianDay: jd)
        default:
            guard let vector = geocentricEcliptic(of: body, julianDay: jd) else { return nil }
            return equatorialFromEcliptic(vector, obliquityDegrees: 23.43928)
        }
    }

    static func distanceAU(of body: EphemerisBody, julianDay jd: Double) -> Double? {
        guard body != .earth,
              let vector = geocentricEcliptic(of: body, julianDay: jd) else { return nil }
        return (vector.x * vector.x + vector.y * vector.y + vector.z * vector.z).squareRoot()
    }

    static func lightTravelSeconds(distanceAU: Double) -> Double {
        distanceAU * auKilometers / lightSpeedKilometersPerSecond
    }

    static func moonPhase(julianDay jd: Double) -> MoonPhase {
        Moon.phase(julianDay: jd)
    }

    static func heliocentricEcliptic(of body: EphemerisBody, julianDay jd: Double) -> SIMD3Double? {
        guard let name = PlanetElements.name(for: body) else { return nil }
        return PlanetElements.heliocentric(name, julianDay: jd)
    }

    private static func geocentricEcliptic(of body: EphemerisBody, julianDay jd: Double) -> SIMD3Double? {
        if body == .sun {
            guard let earth = PlanetElements.heliocentric(.emb, julianDay: jd) else { return nil }
            return SIMD3Double(x: -earth.x, y: -earth.y, z: -earth.z)
        }
        guard let name = PlanetElements.name(for: body),
              let planet = PlanetElements.heliocentric(name, julianDay: jd),
              let earth = PlanetElements.heliocentric(.emb, julianDay: jd)
        else { return nil }
        return planet - earth
    }

    static func equatorialFromEcliptic(
        _ vector: SIMD3Double, obliquityDegrees: Double
    ) -> EquatorialCoordinate {
        let eps = obliquityDegrees * .pi / 180
        let ye = vector.y * cos(eps) - vector.z * sin(eps)
        let ze = vector.y * sin(eps) + vector.z * cos(eps)
        var ra = atan2(ye, vector.x) * 180 / .pi
        if ra < 0 { ra += 360 }
        let dec = atan2(ze, (vector.x * vector.x + ye * ye).squareRoot()) * 180 / .pi
        return EquatorialCoordinate(raHours: ra / 15, decDegrees: dec)
    }
}

struct SIMD3Double: Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double

    static func - (a: SIMD3Double, b: SIMD3Double) -> SIMD3Double {
        SIMD3Double(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z)
    }
}

struct MoonPhase: Equatable, Sendable {
    var illuminatedFraction: Double
    var waxing: Bool
    var ageDays: Double
}
