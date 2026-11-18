import Foundation

enum PlanetName: String, Sendable {
    case mercury, venus, emb, mars, jupiter, saturn, uranus, neptune
}

enum PlanetElements {
    struct Elements: Sendable {
        var base: [Double]
        var rate: [Double]
    }

    static func name(for body: EphemerisBody) -> PlanetName? {
        switch body {
        case .mercury: .mercury
        case .venus: .venus
        case .earth: .emb
        case .mars: .mars
        case .jupiter: .jupiter
        case .saturn: .saturn
        case .uranus: .uranus
        case .neptune: .neptune
        case .sun, .moon: nil
        }
    }

    static let table: [PlanetName: Elements] = [
        .mercury: Elements(
            base: [0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593],
            rate: [0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081]
        ),
        .venus: Elements(
            base: [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255],
            rate: [0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418]
        ),
        .emb: Elements(
            base: [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0],
            rate: [0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0]
        ),
        .mars: Elements(
            base: [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891],
            rate: [0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343]
        ),
        .jupiter: Elements(
            base: [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909],
            rate: [-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106]
        ),
        .saturn: Elements(
            base: [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448],
            rate: [-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794]
        ),
        .uranus: Elements(
            base: [19.18916464, 0.04725744, 0.77263783, 313.23810451, 170.95427630, 74.01692503],
            rate: [-0.00196176, -0.00004397, -0.00242939, 428.48202785, 0.40805281, 0.04240589]
        ),
        .neptune: Elements(
            base: [30.06992276, 0.00859048, 1.77004347, -55.12002969, 44.96476227, 131.78422574],
            rate: [0.00026291, 0.00005105, 0.00035372, 218.45945325, -0.32241464, -0.00508664]
        )
    ]

    static func heliocentric(_ name: PlanetName, julianDay jd: Double) -> SIMD3Double? {
        guard let elements = table[name] else { return nil }
        let t = (jd - Ephemeris.j2000) / 36525
        let a = elements.base[0] + elements.rate[0] * t
        let e = elements.base[1] + elements.rate[1] * t
        let inclination = (elements.base[2] + elements.rate[2] * t) * .pi / 180
        let meanLongitude = elements.base[3] + elements.rate[3] * t
        let longitudePerihelion = elements.base[4] + elements.rate[4] * t
        let longitudeNode = (elements.base[5] + elements.rate[5] * t) * .pi / 180
        let argumentPerihelion = longitudePerihelion * .pi / 180 - longitudeNode
        var meanAnomaly = (meanLongitude - longitudePerihelion)
            .truncatingRemainder(dividingBy: 360)
        meanAnomaly = (meanAnomaly + 540).truncatingRemainder(dividingBy: 360) - 180
        let m = meanAnomaly * .pi / 180
        var eccentricAnomaly = m + e * sin(m)
        for _ in 0..<50 {
            let deltaM = meanAnomaly - (eccentricAnomaly * 180 / .pi - e * 180 / .pi * sin(eccentricAnomaly))
            let deltaE = deltaM * .pi / 180 / (1 - e * cos(eccentricAnomaly))
            eccentricAnomaly += deltaE
            if abs(deltaE) < 1e-9 { break }
        }
        let xp = a * (cos(eccentricAnomaly) - e)
        let yp = a * (1 - e * e).squareRoot() * sin(eccentricAnomaly)
        let cw = cos(argumentPerihelion), sw = sin(argumentPerihelion)
        let co = cos(longitudeNode), so = sin(longitudeNode)
        let ci = cos(inclination), si = sin(inclination)
        return SIMD3Double(
            x: (cw * co - sw * so * ci) * xp + (-sw * co - cw * so * ci) * yp,
            y: (cw * so + sw * co * ci) * xp + (-sw * so + cw * co * ci) * yp,
            z: sw * si * xp + cw * si * yp
        )
    }
}
