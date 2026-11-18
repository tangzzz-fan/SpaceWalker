import Foundation

enum Moon {
    struct Term: Sendable {
        var d: Double
        var m: Double
        var mp: Double
        var f: Double
        var coefficient: Double

        init(_ d: Double, _ m: Double, _ mp: Double, _ f: Double, _ coefficient: Double) {
            self.d = d
            self.m = m
            self.mp = mp
            self.f = f
            self.coefficient = coefficient
        }
    }

    static let longitudeTerms: [Term] = [
        Term(0, 0, 1, 0, 6288774),
        Term(2, 0, -1, 0, 1274027),
        Term(2, 0, 0, 0, 658314),
        Term(0, 0, 2, 0, 213618),
        Term(0, 1, 0, 0, -185116),
        Term(0, 0, 0, 2, -114332),
        Term(2, 0, -2, 0, 58793),
        Term(2, -1, -1, 0, 57066),
        Term(2, 0, 1, 0, 53322),
        Term(2, -1, 0, 0, 45758),
        Term(0, 1, -1, 0, -40923),
        Term(1, 0, 0, 0, -34720),
        Term(0, 1, 1, 0, -30383),
        Term(2, 0, 0, -2, 15327),
        Term(0, 0, 1, 2, -12528),
        Term(0, 0, 1, -2, 10980),
        Term(4, 0, -1, 0, 10675),
        Term(0, 0, 3, 0, 10034),
        Term(4, 0, -2, 0, 8548),
        Term(2, 1, -1, 0, -7888),
        Term(2, 1, 0, 0, -6766),
        Term(1, 0, -1, 0, -5163),
        Term(1, 1, 0, 0, 4987),
        Term(2, -1, 1, 0, 4036),
        Term(2, 0, 2, 0, 3994),
        Term(4, 0, 0, 0, 3861),
        Term(2, 0, -3, 0, 3665),
        Term(0, 1, -2, 0, -2689),
        Term(2, 0, -1, 2, -2602),
        Term(2, -1, -2, 0, 2390),
        Term(1, 0, 1, 0, -2348),
        Term(2, -2, 0, 0, 2236),
        Term(0, 1, 2, 0, -2120),
        Term(0, 2, 0, 0, -2069),
        Term(2, -2, -1, 0, 2048),
        Term(2, 0, 1, -2, -1773),
        Term(2, 0, 0, 2, -1595),
        Term(4, -1, -1, 0, 1215),
        Term(0, 0, 2, 2, -1110),
        Term(3, 0, -1, 0, -892),
        Term(2, 1, 1, 0, -810),
        Term(4, -1, -2, 0, 759),
        Term(0, 2, -1, 0, -713),
        Term(2, 2, -1, 0, -700),
        Term(2, 1, -2, 0, 691),
        Term(2, -1, 0, -2, 596),
        Term(4, 0, 1, 0, 549),
        Term(0, 0, 4, 0, 537),
        Term(4, -1, 0, 0, 520),
        Term(1, 0, -2, 0, -487),
        Term(2, -1, 2, 0, -399),
        Term(2, 0, 2, -2, -381),
        Term(1, 1, 1, 0, 351),
        Term(3, 0, -2, 0, -340),
        Term(4, 0, -3, 0, 330),
        Term(2, -1, 1, 2, 327),
        Term(0, 2, 1, 0, -323),
        Term(1, 1, -1, 0, 299),
        Term(2, 0, 3, 0, 294),
        Term(2, 0, -1, -2, 0)
    ]

    static let latitudeTerms: [Term] = [
        Term(0, 0, 0, 1, 5128122),
        Term(0, 0, 1, 1, 280602),
        Term(0, 0, 1, -1, 277693),
        Term(2, 0, 0, -1, 173237),
        Term(2, 0, -1, 1, 55413),
        Term(2, 0, -1, -1, 46271),
        Term(2, 0, 0, 1, 32573),
        Term(0, 0, 2, 1, 17198),
        Term(2, 0, 1, -1, 9266),
        Term(0, 0, 2, -1, 8822),
        Term(2, -1, 0, -1, 8216),
        Term(2, 0, -2, -1, 4324),
        Term(2, 0, 1, 1, 4200),
        Term(2, 1, 0, -1, -3359),
        Term(2, -1, -1, 1, 2463),
        Term(2, -1, 0, 1, 2211),
        Term(2, -1, -1, -1, 2065),
        Term(0, 1, -1, -1, -1870),
        Term(4, 0, -1, -1, 1828),
        Term(0, 1, 0, 1, -1794),
        Term(0, 0, 0, 3, -1749),
        Term(0, 1, -1, 1, -1565),
        Term(1, 0, 0, 1, -1491),
        Term(0, 1, 1, 1, -1475),
        Term(0, 1, 1, -1, -1410),
        Term(0, 1, 0, -1, -1344),
        Term(1, 0, 0, -1, -1335),
        Term(0, 0, 3, 1, 1107),
        Term(4, 0, 0, -1, 1021),
        Term(4, 0, -1, 1, 833)
    ]

    static let distanceTerms: [Term] = [
        Term(0, 0, 1, 0, -20905355), Term(2, 0, -1, 0, -3699111),
        Term(2, 0, 0, 0, -2955968), Term(0, 0, 2, 0, -569925),
        Term(0, 1, 0, 0, 48888), Term(0, 0, 0, 2, -3149),
        Term(2, 0, -2, 0, 246158), Term(2, -1, -1, 0, -152138),
        Term(2, 0, 1, 0, -170733), Term(2, -1, 0, 0, -204586),
        Term(0, 1, -1, 0, -129620), Term(1, 0, 0, 0, 108743),
        Term(0, 1, 1, 0, 104755), Term(2, 0, 0, -2, 10321),
        Term(0, 0, 1, -2, 79661), Term(4, 0, -1, 0, -34782),
        Term(0, 0, 3, 0, -23210), Term(4, 0, -2, 0, -21636),
        Term(2, 1, -1, 0, 24208), Term(2, 1, 0, 0, 30824),
        Term(1, 0, -1, 0, -8379), Term(1, 1, 0, 0, -16675),
        Term(2, -1, 1, 0, -12831), Term(2, 0, 2, 0, -10445),
        Term(4, 0, 0, 0, -11650), Term(2, 0, -3, 0, 14403),
        Term(0, 1, -2, 0, -7003), Term(2, -1, -2, 0, 10056),
        Term(1, 0, 1, 0, 6322), Term(2, -2, 0, 0, -9884)
    ]

    struct Arguments {
        var t: Double
        var lp: Double
        var d: Double
        var m: Double
        var mp: Double
        var f: Double
        var e: Double
        var a1: Double
        var a2: Double
        var a3: Double
    }

    static func arguments(julianDay jd: Double) -> Arguments {
        let t = (jd - Ephemeris.j2000) / 36525
        return Arguments(
            t: t,
            lp: 218.3164477 + 481267.88123421 * t - 0.0015786 * t * t,
            d: 297.8501921 + 445267.1114034 * t - 0.0018819 * t * t,
            m: 357.5291092 + 35999.0502909 * t - 0.0001536 * t * t,
            mp: 134.9633964 + 477198.8675055 * t + 0.0087414 * t * t,
            f: 93.2720950 + 483202.0175233 * t - 0.0036539 * t * t,
            e: 1 - 0.002516 * t - 0.0000074 * t * t,
            a1: 119.75 + 131.849 * t,
            a2: 53.09 + 479264.290 * t,
            a3: 313.45 + 481266.484 * t
        )
    }

    private static func sigma(_ terms: [Term], _ a: Arguments) -> Double {
        let deg = Double.pi / 180
        var total = 0.0
        for term in terms {
            let angle = (term.d * a.d + term.m * a.m + term.mp * a.mp + term.f * a.f) * deg
            let factor = pow(a.e, abs(term.m))
            total += term.coefficient * factor * sin(angle)
        }
        return total
    }

    static func eclipticLongitudeLatitude(julianDay jd: Double) -> (longitude: Double, latitude: Double) {
        let a = arguments(julianDay: jd)
        let deg = Double.pi / 180
        let lonSum = sigma(longitudeTerms, a)
            + 3958 * sin(a.a1 * deg)
            + 1962 * sin((a.lp - a.f) * deg)
            + 318 * sin(a.a2 * deg)
        let latSum = sigma(latitudeTerms, a)
            - 2235 * sin(a.lp * deg)
            + 382 * sin(a.a3 * deg)
            + 175 * sin((a.a1 - a.f) * deg)
            + 175 * sin((a.a1 + a.f) * deg)
            + 127 * sin((a.lp - a.mp) * deg)
            - 115 * sin((a.lp + a.mp) * deg)
        var longitude = (a.lp + lonSum / 1_000_000).truncatingRemainder(dividingBy: 360)
        if longitude < 0 { longitude += 360 }
        return (longitude, latSum / 1_000_000)
    }

    static func distanceKilometers(julianDay jd: Double) -> Double {
        let a = arguments(julianDay: jd)
        let deg = Double.pi / 180
        var total = 0.0
        for term in distanceTerms {
            let angle = (term.d * a.d + term.m * a.m + term.mp * a.mp + term.f * a.f) * deg
            total += term.coefficient * pow(a.e, abs(term.m)) * cos(angle)
        }
        return 385000.56 + total / 1000
    }

    static func equatorial(julianDay jd: Double) -> EquatorialCoordinate {
        let a = arguments(julianDay: jd)
        let (longitude, latitude) = eclipticLongitudeLatitude(julianDay: jd)
        let deg = Double.pi / 180
        let obliquity = (23.439291 - 0.0130042 * a.t) * deg
        let l = longitude * deg, b = latitude * deg
        let x = cos(b) * cos(l)
        let y = cos(b) * sin(l)
        let z = sin(b)
        let ye = y * cos(obliquity) - z * sin(obliquity)
        let ze = y * sin(obliquity) + z * cos(obliquity)
        let raDate = atan2(ye, x)
        let decDate = atan2(ze, (x * x + ye * ye).squareRoot())
        return precessToJ2000(raDate: raDate, decDate: decDate, t: a.t)
    }

    private static func precessToJ2000(raDate: Double, decDate: Double, t: Double) -> EquatorialCoordinate {
        let arcsec = Double.pi / 180 / 3600
        let zeta = (2306.2181 * t + 0.30188 * t * t + 0.017998 * t * t * t) * arcsec
        let z = (2306.2181 * t + 1.09468 * t * t + 0.018203 * t * t * t) * arcsec
        let theta = (2004.3109 * t - 0.42665 * t * t - 0.041833 * t * t * t) * arcsec
        let xd = cos(decDate) * cos(raDate)
        let yd = cos(decDate) * sin(raDate)
        let zd = sin(decDate)
        let cz = cos(zeta), sz = sin(zeta)
        let cZ = cos(z), sZ = sin(z)
        let ct = cos(theta), st = sin(theta)
        let r1x = cz * cZ * ct - sz * sZ
        let r1y = -sz * cZ * ct - cz * sZ
        let r1z = -cZ * st
        let r2x = cz * sZ * ct + sz * cZ
        let r2y = -sz * sZ * ct + cz * cZ
        let r2z = -sZ * st
        let r3x = cz * st
        let r3y = -sz * st
        let r3z = ct
        let x0 = r1x * xd + r2x * yd + r3x * zd
        let y0 = r1y * xd + r2y * yd + r3y * zd
        let z0 = r1z * xd + r2z * yd + r3z * zd
        var ra = atan2(y0, x0) * 180 / .pi
        if ra < 0 { ra += 360 }
        let dec = atan2(z0, (x0 * x0 + y0 * y0).squareRoot()) * 180 / .pi
        return EquatorialCoordinate(raHours: ra / 15, decDegrees: dec)
    }

    static func phase(julianDay jd: Double) -> MoonPhase {
        let a = arguments(julianDay: jd)
        let deg = Double.pi / 180
        let elongation = (a.lp - sunMeanLongitude(julianDay: jd))
            .truncatingRemainder(dividingBy: 360)
        let normalized = elongation < 0 ? elongation + 360 : elongation
        let phaseAngle = (180 - normalized) * deg
        let illuminated = (1 + cos(phaseAngle)) / 2
        let synodicMonth = 29.530588853
        let age = normalized / 360 * synodicMonth
        return MoonPhase(illuminatedFraction: illuminated, waxing: normalized < 180, ageDays: age)
    }

    private static func sunMeanLongitude(julianDay jd: Double) -> Double {
        let t = (jd - Ephemeris.j2000) / 36525
        return 280.46646 + 36000.76983 * t
    }
}
