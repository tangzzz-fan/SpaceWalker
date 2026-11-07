import Foundation
import simd

struct TonightPick: Identifiable, Equatable, Sendable {
    var group: SkyGroup
    var altitude: Double
    var azimuth: Double
    var bestMonths: [Int]
    var magnitude: Double

    var id: String {
        group.id
    }

    var isWellPlaced: Bool {
        altitude >= 30
    }

    var altitudeText: String {
        String(format: "高度 %.0f° · %@", altitude, SkySeason.directionLabel(azimuth: azimuth))
    }

    var seasonText: String {
        SkySeason.label(bestMonths)
    }
}

enum SkySeason {
    static func bestMonths(rightAscensionHours: Double) -> [Int] {
        let index = Int((9.0 + rightAscensionHours / 2).rounded()) % 12
        let month = (index + 12) % 12 + 1
        return [(month + 10) % 12 + 1, month, month % 12 + 1]
    }

    static func label(_ months: [Int]) -> String {
        guard let first = months.first, let last = months.last, months.count >= 2 else { return "" }
        if first > last {
            return "\(first) 月 – 次年 \(last) 月"
        }
        return "\(first)–\(last) 月"
    }

    static func coordinate(_ group: SkyGroup, stars: [Star]) -> (rightAscension: Double, declination: Double)? {
        guard let vector = SkyGroupIndex.anchor(group, stars: stars) else { return nil }
        var hours = atan2(-Double(vector.z), Double(vector.x)) / (2 * Double.pi) * 24
        if hours < 0 {
            hours += 24
        }
        return (hours, asin(Double(vector.y)) * 180 / .pi)
    }

    static func rank(
        groups: [SkyGroup],
        stars: [Star],
        latitude: Double,
        longitude: Double,
        date: Date = Date(),
        minimumAltitude: Double = 12,
        limit: Int = 6
    ) -> [TonightPick] {
        let sidereal = Astronomy.localSiderealDegrees(
            julianDay: Astronomy.julianDay(date),
            longitude: longitude
        )
        var picks: [TonightPick] = []
        for group in groups where group.kind == .constellation {
            guard let coordinate = coordinate(group, stars: stars) else { continue }
            let horizontal = Astronomy.horizontal(
                rightAscensionHours: coordinate.rightAscension,
                declinationDegrees: coordinate.declination,
                siderealDegrees: sidereal,
                latitude: latitude
            )
            guard horizontal.altitude > minimumAltitude else { continue }
            let brightest = SkyGroupIndex.brightest(group, stars: stars)
            picks.append(
                TonightPick(
                    group: group,
                    altitude: horizontal.altitude,
                    azimuth: horizontal.azimuth,
                    bestMonths: bestMonths(rightAscensionHours: coordinate.rightAscension),
                    magnitude: brightest?.magnitude ?? 5
                )
            )
        }
        return picks
            .sorted { score($0) > score($1) }
            .prefix(limit)
            .map { $0 }
    }

    static func score(_ pick: TonightPick) -> Double {
        let altitude = max(0, min(1, pick.altitude / 90))
        let brightness = max(0, min(1, (4.5 - pick.magnitude) / 4.5))
        return altitude * 0.65 + brightness * 0.35
    }

    static func directionLabel(azimuth: Double) -> String {
        let names = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
        let index = Int((Astronomy.normalized(azimuth) + 22.5) / 45) % 8
        return names[index]
    }
}
