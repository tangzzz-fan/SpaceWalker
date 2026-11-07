import Foundation
import simd

enum Astronomy {
    static let j2000Epoch = 2451545.0
    static let polarisDeclination = 89.264

    struct Horizontal: Equatable, Sendable {
        var altitude: Double
        var azimuth: Double
    }

    static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86400 + 2440587.5
    }

    static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    static func greenwichSiderealDegrees(julianDay: Double) -> Double {
        normalized(280.46061837 + 360.98564736629 * (julianDay - j2000Epoch))
    }

    static func localSiderealDegrees(julianDay: Double, longitude: Double) -> Double {
        normalized(greenwichSiderealDegrees(julianDay: julianDay) + longitude)
    }

    static func horizontal(
        rightAscensionHours: Double,
        declinationDegrees: Double,
        siderealDegrees: Double,
        latitude: Double
    ) -> Horizontal {
        let hourAngle = (siderealDegrees - rightAscensionHours * 15) * .pi / 180
        let declination = declinationDegrees * .pi / 180
        let latitudeRadians = latitude * .pi / 180

        let sinAltitude = sin(declination) * sin(latitudeRadians)
            + cos(declination) * cos(latitudeRadians) * cos(hourAngle)
        let altitude = asin(min(max(sinAltitude, -1), 1))

        let east = -cos(declination) * sin(hourAngle)
        let north = sin(declination) * cos(latitudeRadians)
            - cos(declination) * sin(latitudeRadians) * cos(hourAngle)

        return Horizontal(
            altitude: altitude * 180 / .pi,
            azimuth: normalized(atan2(east, north) * 180 / .pi)
        )
    }

    static func worldDirection(altitude: Double, azimuth: Double) -> SIMD3<Float> {
        let altitudeRadians = altitude * .pi / 180
        let azimuthRadians = azimuth * .pi / 180
        return SIMD3<Float>(
            Float(cos(altitudeRadians) * sin(azimuthRadians)),
            Float(sin(altitudeRadians)),
            Float(-cos(altitudeRadians) * cos(azimuthRadians))
        )
    }

    static func equatorialToHorizontalRotation(siderealDegrees: Double, latitude: Double) -> simd_quatf {
        let pole = basisDirection(raHours: 0, decDegrees: 90, siderealDegrees: siderealDegrees, latitude: latitude)
        let vernal = basisDirection(raHours: 0, decDegrees: 0, siderealDegrees: siderealDegrees, latitude: latitude)
        let sixthHour = basisDirection(raHours: 18, decDegrees: 0, siderealDegrees: siderealDegrees, latitude: latitude)
        return simd_quatf(simd_float3x3(columns: (vernal, pole, sixthHour)))
    }

    static func sceneAzimuth(_ forward: SIMD3<Float>) -> Double {
        normalized(Double(atan2(forward.x, -forward.z)) * 180 / .pi)
    }

    static func fieldRotationDegrees(trueHeading: Double, sceneAzimuth: Double) -> Double {
        normalized(trueHeading - sceneAzimuth)
    }

    static func yawRotation(degrees: Double) -> simd_quatf {
        simd_quatf(angle: Float(degrees * .pi / 180), axis: SIMD3<Float>(0, 1, 0))
    }

    private static func basisDirection(
        raHours: Double,
        decDegrees: Double,
        siderealDegrees: Double,
        latitude: Double
    ) -> SIMD3<Float> {
        let horizontal = horizontal(
            rightAscensionHours: raHours,
            declinationDegrees: decDegrees,
            siderealDegrees: siderealDegrees,
            latitude: latitude
        )
        return worldDirection(altitude: horizontal.altitude, azimuth: horizontal.azimuth)
    }
}
