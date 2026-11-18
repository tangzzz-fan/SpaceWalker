import Foundation
import simd

enum SkyBodies {
    static let bodies: [EphemerisBody] = [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn]

    static let magnitudes: [EphemerisBody: Double] = [
        .sun: -26.7,
        .moon: -12.7,
        .mercury: -0.5,
        .venus: -4.3,
        .mars: -1.5,
        .jupiter: -2.5,
        .saturn: 0.5,
    ]

    static let colorIndices: [EphemerisBody: Double] = [
        .sun: 0.65,
        .moon: 0.0,
        .mercury: 0.9,
        .venus: 0.1,
        .mars: 1.6,
        .jupiter: 0.3,
        .saturn: 0.6,
    ]

    static let names: [EphemerisBody: String] = [
        .sun: "太阳",
        .moon: "月球",
        .mercury: "水星",
        .venus: "金星",
        .mars: "火星",
        .jupiter: "木星",
        .saturn: "土星",
    ]

    static let planetDisplayRadius: Float = 0.42
    static let sunDisplayRadius: Float = 1.1
    static let moonDisplayRadius: Float = 0.95

    static func displayRadius(for body: EphemerisBody) -> Float {
        switch body {
        case .sun: sunDisplayRadius
        case .moon: moonDisplayRadius
        default: planetDisplayRadius
        }
    }

    static func star(for body: EphemerisBody, julianDay: Double) -> Star? {
        guard bodies.contains(body),
              let coordinate = Ephemeris.equatorial(of: body, julianDay: julianDay)
        else { return nil }
        return Star(
            rightAscensionHours: coordinate.raHours,
            declinationDegrees: coordinate.decDegrees,
            magnitude: magnitudes[body] ?? 0,
            colorIndex: colorIndices[body] ?? 0,
            name: names[body] ?? body.rawValue,
            constellation: "",
            hipparcos: nil,
            distanceLightYears: nil
        )
    }

    static func stars(julianDay: Double) -> [Star] {
        bodies.compactMap { star(for: $0, julianDay: julianDay) }
    }

    static func body(for star: Star) -> EphemerisBody? {
        guard star.hipparcos == nil else { return nil }
        return bodies.first { names[$0] == star.name }
    }

    static func solarBodyID(for body: EphemerisBody) -> BodyID? {
        switch body {
        case .sun: .sun
        case .mercury: .mercury
        case .venus: .venus
        case .mars: .mars
        case .jupiter: .jupiter
        case .saturn: .saturn
        default: nil
        }
    }

    static func distanceLine(for star: Star) -> String? {
        guard let lightYears = star.distanceLightYears else { return nil }
        let distance = lightYears >= 100
            ? String(format: "%.0f 光年", lightYears)
            : String(format: "%.1f 光年", lightYears)
        let years = lightYears >= 100
            ? String(format: "%.0f", lightYears)
            : String(format: "%.1f", lightYears)
        return "距离 \(distance) · 这束光出发于 \(years) 年前"
    }
}

enum MoonPhaseGlyph {
    static func mesh(
        phase: MoonPhase,
        radius: Float,
        segments: Int = 28
    ) -> StarMeshData {
        let lit = min(max(Float(phase.illuminatedFraction), 0), 1)
        let side: Float = phase.waxing ? 1 : -1
        let terminatorScale = 1 - 2 * lit
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for step in 0...segments {
            let angle = -Float.pi / 2 + Float(step) / Float(segments) * Float.pi
            let y = sin(angle) * radius
            let width = cos(angle) * radius
            positions.append(SIMD3(side * width, y, 0))
            normals.append(SIMD3(0, 0, 1))
            positions.append(SIMD3(side * width * terminatorScale, y, 0))
            normals.append(SIMD3(0, 0, 1))
        }
        for step in 0..<segments {
            let limb = UInt32(step * 2)
            let terminator = limb + 1
            let nextLimb = limb + 2
            let nextTerminator = terminator + 2
            if side > 0 {
                indices.append(contentsOf: [limb, nextLimb, terminator])
                indices.append(contentsOf: [terminator, nextLimb, nextTerminator])
            } else {
                indices.append(contentsOf: [limb, terminator, nextLimb])
                indices.append(contentsOf: [terminator, nextTerminator, nextLimb])
            }
        }
        return StarMeshData(positions: positions, normals: normals, indices: indices)
    }
}