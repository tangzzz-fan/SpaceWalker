import Foundation
import simd

enum EarthOrbitConstants {
    static let earthRadiusKilometers: Double = 6371
    static let moonRadiusKilometers: Double = 1737.4
    static let earthMoonDistanceKilometers: Double = 384_400
    static let tiangongAltitudeKilometers: Double = 350
    static let tiangongInclinationDegrees: Double = 42.77
    static let tiangongPeriodMinutes: Double = 91.5
    static let basketballDiameterMeters: Double = 0.24

    static var tiangongOrbitRadiusKilometers: Double {
        earthRadiusKilometers + tiangongAltitudeKilometers
    }

    static var tiangongHeightAboveBasketballMillimeters: Double {
        tiangongAltitudeKilometers / (2 * earthRadiusKilometers) * basketballDiameterMeters * 1000
    }

    static var analogyText: String {
        String(
            format: "地球若是篮球，天宫只在球面上方约 %.0f 毫米",
            tiangongHeightAboveBasketballMillimeters.rounded()
        )
    }
}

enum EarthOrbitCameraStop: Equatable, Sendable {
    static let transitionDuration: Double = 0.4

    case overview
    case orbitClose

    var rig: OrbitRig {
        switch self {
        case .overview: OrbitRig(yaw: 0.38, pitch: 0.52, distance: 16.0)
        case .orbitClose: OrbitRig(yaw: 0.38, pitch: 0.30, distance: 5.2)
        }
    }
}

struct EarthOrbitGeometry {
    static let earthDisplayRadius: Float = 1.0
    static let kilometersPerDisplayUnit: Double = EarthOrbitConstants.earthRadiusKilometers

    static var moonDisplayRadius: Float {
        Float(EarthOrbitConstants.moonRadiusKilometers / kilometersPerDisplayUnit)
    }

    static var moonDisplayDistance: Float {
        Float(EarthOrbitConstants.earthMoonDistanceKilometers / kilometersPerDisplayUnit)
    }

    static var tiangongOrbitDisplayRadius: Float {
        Float(EarthOrbitConstants.tiangongOrbitRadiusKilometers / kilometersPerDisplayUnit)
    }

    static func moonPosition(julianDay: Double) -> SIMD3<Float> {
        let (longitude, latitude) = Moon.eclipticLongitudeLatitude(julianDay: julianDay)
        let eps = 23.43928 * Double.pi / 180
        let l = longitude * .pi / 180
        let b = latitude * .pi / 180
        let x = cos(b) * cos(l)
        let y = cos(b) * sin(l)
        let z = sin(b)
        let ye = y * cos(eps) - z * sin(eps)
        let ze = y * sin(eps) + z * cos(eps)
        let direction = simd_normalize(SIMD3(Float(x), Float(ze), Float(-ye)))
        return direction * moonDisplayDistance
    }

    static func tiangongPosition(phase: Double) -> SIMD3<Float> {
        let inclination = EarthOrbitConstants.tiangongInclinationDegrees * Double.pi / 180
        let theta = phase * 2 * Double.pi
        let radius = Double(tiangongOrbitDisplayRadius)
        let x = cos(theta) * radius
        let zFlat = sin(theta) * radius
        let y = zFlat * sin(inclination)
        let z = zFlat * cos(inclination)
        return SIMD3(Float(x), Float(y), Float(z))
    }

    static func groundTrack(phase: Double) -> (latitudeDegrees: Double, longitudeDegrees: Double) {
        let inclination = EarthOrbitConstants.tiangongInclinationDegrees
        let theta = phase * 360
        let latitude = asin(sin(inclination * .pi / 180) * sin(theta * .pi / 180)) * 180 / .pi
        var longitude = atan2(
            cos(inclination * .pi / 180) * sin(theta * .pi / 180),
            cos(theta * .pi / 180)
        ) * 180 / .pi
        longitude -= phase * 360 * EarthOrbitConstants.tiangongPeriodMinutes / 1436.07
        longitude = (longitude + 540).truncatingRemainder(dividingBy: 360) - 180
        return (latitude, longitude)
    }

    static func sunDirection(julianDay: Double) -> SIMD3<Float> {
        guard let sun = Ephemeris.equatorial(of: .sun, julianDay: julianDay) else {
            return SIMD3(0, 0, 1)
        }
        let ra = sun.raHours / 24 * 2 * Double.pi
        let dec = sun.decDegrees * Double.pi / 180
        return simd_normalize(SIMD3(
            Float(cos(dec) * cos(ra)),
            Float(sin(dec)),
            Float(-cos(dec) * sin(ra))
        ))
    }
}
