import Foundation
import simd

/// 093：聚焦行星时显示的主要卫星。非聚焦态不显示（票面硬约束）。
/// 距离与直径取 NASA Planetary Fact Sheet 量级；显示尺寸沿用教学比例
/// （与 SolarLayout.bodyRadius 同一指数），保证「卫星比行星小」一眼可读。
struct SolarMoon: Equatable, Sendable {
    let id: String
    let name: String
    let parent: BodyID
    let diameterKilometers: Double
    let orbitRadiusKilometers: Double
    let orbitalPeriodDays: Double
    let colorHex: UInt32
}

enum SolarSatellites {
    static let moons: [SolarMoon] = [
        SolarMoon(
            id: "moon", name: "月球", parent: .earth,
            diameterKilometers: 3_475, orbitRadiusKilometers: 384_400,
            orbitalPeriodDays: 27.32, colorHex: 0xB8B8B8
        ),
        SolarMoon(
            id: "io", name: "木卫一", parent: .jupiter,
            diameterKilometers: 3_643, orbitRadiusKilometers: 421_700,
            orbitalPeriodDays: 1.77, colorHex: 0xD8C060
        ),
        SolarMoon(
            id: "europa", name: "木卫二", parent: .jupiter,
            diameterKilometers: 3_122, orbitRadiusKilometers: 671_034,
            orbitalPeriodDays: 3.55, colorHex: 0xC8B8A0
        ),
        SolarMoon(
            id: "ganymede", name: "木卫三", parent: .jupiter,
            diameterKilometers: 5_268, orbitRadiusKilometers: 1_070_412,
            orbitalPeriodDays: 7.15, colorHex: 0x988878
        ),
        SolarMoon(
            id: "callisto", name: "木卫四", parent: .jupiter,
            diameterKilometers: 4_821, orbitRadiusKilometers: 1_882_709,
            orbitalPeriodDays: 16.69, colorHex: 0x786858
        ),
        SolarMoon(
            id: "titan", name: "土卫六", parent: .saturn,
            diameterKilometers: 5_150, orbitRadiusKilometers: 1_221_870,
            orbitalPeriodDays: 15.95, colorHex: 0xD0A860
        ),
    ]

    static func moons(of parent: BodyID) -> [SolarMoon] {
        moons.filter { $0.parent == parent }
    }

    /// 卫星显示半径：与行星同一教学指数，但整体再缩 0.55，
    /// 避免聚焦木星时伽利略四星抢过木星本体。
    static func displayRadius(for moon: SolarMoon) -> Float {
        let scaled = Float(pow(
            moon.diameterKilometers / SolarLayout.earthDiameterKilometers,
            SolarLayout.radiusExponent
        )) * SolarLayout.earthDisplayRadius
        return scaled * 0.55
    }

    /// 卫星轨道显示半径：以行星显示半径为基准向外排布，
    /// 按真实轨道半径比例压缩（否则木卫四会飞出画面）。
    static func orbitDisplayRadius(for moon: SolarMoon) -> Float {
        guard let parent = SolarSystem.body(moon.parent) else { return 0 }
        let parentRadius = SolarLayout.bodyRadius(for: parent)
        let ratio = moon.orbitRadiusKilometers / 384_400
        return parentRadius * (1.6 + Float(pow(ratio, 0.5)) * 1.4)
    }

    /// 卫星位置：真实周期驱动相位，轨道面近似黄道面（教学示意，不标倾角）。
    static func position(for moon: SolarMoon, julianDay: Double) -> SIMD3<Float> {
        let phase = (julianDay / moon.orbitalPeriodDays).truncatingRemainder(dividingBy: 1)
        let theta = Float(phase * 2 * .pi)
        let radius = orbitDisplayRadius(for: moon)
        return SIMD3(cos(theta) * radius, 0, sin(theta) * radius)
    }
}

/// 093：小行星带与柯伊伯带。粒子环用「一个实体 + 一份合并网格」呈现，
/// 每带只占 1 实体 / 1 draw call；不参与拾取（pick 只遍历行星）。
enum SolarBelts {
    static let asteroidCount = 220
    static let kuiperCount = 260
    /// 教学布局下的轨道半径区间（AU^orbitExponent 压缩后）。
    static let asteroidRangeAU: ClosedRange<Double> = 2.1...3.3
    static let kuiperRangeAU: ClosedRange<Double> = 30...48

    struct Particle: Equatable, Sendable {
        let position: SIMD3<Float>
        let radius: Float
    }

    /// 确定性伪随机（种子固定）：带的位置每次构建一致，截图与预算可复现。
    static func particles(
        count: Int,
        rangeAU: ClosedRange<Double>,
        seed: UInt64
    ) -> [Particle] {
        var state = seed
        func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
        var result: [Particle] = []
        result.reserveCapacity(count)
        for _ in 0..<count {
            let au = rangeAU.lowerBound + next() * (rangeAU.upperBound - rangeAU.lowerBound)
            let orbitRadius = Float(pow(au, SolarLayout.orbitExponent)) * SolarLayout.orbitUnit
            let theta = Float(next() * 2 * .pi)
            let thickness = (Float(next()) - 0.5) * orbitRadius * 0.06
            let radius = 0.004 + Float(next()) * 0.006
            result.append(Particle(
                position: SIMD3(cos(theta) * orbitRadius, thickness, sin(theta) * orbitRadius),
                radius: radius
            ))
        }
        return result
    }

    static var asteroidParticles: [Particle] {
        particles(count: asteroidCount, rangeAU: asteroidRangeAU, seed: 0xA57E_2011)
    }

    static var kuiperParticles: [Particle] {
        particles(count: kuiperCount, rangeAU: kuiperRangeAU, seed: 0x4B55_1951)
    }
}