import Foundation

enum ScaleLevel: Int, CaseIterable, Equatable, Hashable, Sendable {
    case sky
    case solar
    case earthOrbit
    case tiangong

    static let defaultLevel: ScaleLevel = .sky

    var depth: Int { rawValue }

    var above: ScaleLevel? { ScaleLevel(rawValue: rawValue - 1) }
    var below: ScaleLevel? { ScaleLevel(rawValue: rawValue + 1) }

    func canDescend(to target: ScaleLevel) -> Bool {
        target == below
    }

    func canAscend(to target: ScaleLevel) -> Bool {
        target.depth < depth
    }

    var title: String { descriptor.title }
    var question: String { descriptor.question }
    var rulerText: String { descriptor.rulerText }
    var rulerRangeText: String { descriptor.rulerRangeText }
    var representativeMeters: Double { descriptor.representativeMeters }
    var rulerRangeMeters: ClosedRange<Double> { descriptor.rulerRangeMeters }
    var handoffRig: OrbitRig { descriptor.handoffRig }

    var descriptor: ScaleLevelDescriptor { Self.descriptors[self]! }

    static let descriptors: [ScaleLevel: ScaleLevelDescriptor] = [
        .sky: ScaleLevelDescriptor(
            title: "星图",
            question: "我看到的光从多远来？",
            rulerText: "4–3000 光年",
            rulerRangeText: "10⁰–10³ 光年",
            representativeMeters: 9.4607e18,
            rulerRangeMeters: 3.7843e16...2.8382e19,
            handoffRig: OrbitRig(yaw: 0.0, pitch: 0.52, distance: OrbitRig.distanceRange.upperBound)
        ),
        .solar: ScaleLevelDescriptor(
            title: "太阳系",
            question: "那颗「亮星」其实是行星，它在哪？",
            rulerText: "0.4–30 AU",
            rulerRangeText: "10⁻¹–10¹ AU",
            representativeMeters: 1.495978707e12,
            rulerRangeMeters: 5.9839e10...4.4879e12,
            handoffRig: OrbitRig()
        ),
        .earthOrbit: ScaleLevelDescriptor(
            title: "地月系",
            question: "天宫离我们有多近？",
            rulerText: "350 km–38 万 km",
            rulerRangeText: "10⁵–10⁸ m",
            representativeMeters: 3.844e8,
            rulerRangeMeters: 3.5e5...3.844e8,
            handoffRig: OrbitRig(yaw: 0.38, pitch: 0.52, distance: 12.0)
        ),
        .tiangong: ScaleLevelDescriptor(
            title: "天宫一号",
            question: "它长什么样、怎么对接？",
            rulerText: "约 10 米",
            rulerRangeText: "10¹ m",
            representativeMeters: 10.4,
            rulerRangeMeters: 3.0...10.4,
            handoffRig: OrbitRig(yaw: 0.38, pitch: 0.35, distance: 8.0)
        )
    ]
}

struct ScaleLevelDescriptor: Equatable, Sendable {
    var title: String
    var question: String
    var rulerText: String
    var rulerRangeText: String
    var representativeMeters: Double
    var rulerRangeMeters: ClosedRange<Double>
    var handoffRig: OrbitRig
}

struct ScaleRuler {
    static let trackDomain: ClosedRange<Double> = 0...20
    static let lightYearMeters: Double = 9.4607e15
    static let astronomicalUnitMeters: Double = 1.495978707e11

    static func readingMeters(from: ScaleLevel, to: ScaleLevel, progress: Double) -> Double {
        readingMeters(fromMeters: from.representativeMeters, toMeters: to.representativeMeters, progress: progress)
    }

    static func readingMeters(fromMeters: Double, toMeters: Double, progress: Double) -> Double {
        let t = min(max(progress, 0), 1)
        let a = log10(max(fromMeters, 1))
        let b = log10(max(toMeters, 1))
        return pow(10, a + (b - a) * t)
    }

    static func easeInOutCubic(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }

    static func trackFraction(meters: Double) -> Double {
        let exponent = log10(max(meters, 1))
        let span = trackDomain.upperBound - trackDomain.lowerBound
        return min(max((exponent - trackDomain.lowerBound) / span, 0), 1)
    }

    static func trackRange(for level: ScaleLevel) -> ClosedRange<Double> {
        trackFraction(meters: level.rulerRangeMeters.lowerBound)
            ... trackFraction(meters: level.rulerRangeMeters.upperBound)
    }

    static func readingText(meters: Double) -> String {
        String(format: "10^%.1f m", log10(max(meters, 1)))
    }
}