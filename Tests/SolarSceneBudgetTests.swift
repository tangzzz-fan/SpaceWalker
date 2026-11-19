import RealityKit
import XCTest
import simd

@testable import SpaceWalker

/// 093：卫星只在聚焦时显示；带是粒子环、不参与拾取；预算不超 FR-C-07 量级。
@MainActor
final class SolarSceneBudgetTests: XCTestCase {
    private func builtScene() -> SolarSystemScene {
        let scene = SolarSystemScene()
        scene.build()
        return scene
    }

    private func node(_ scene: SolarSystemScene, named name: String) -> Entity? {
        func find(_ entity: Entity) -> Entity? {
            if entity.name == name { return entity }
            for child in entity.children {
                if let hit = find(child) { return hit }
            }
            return nil
        }
        return find(scene.root)
    }

    func testMoonsExistForEarthJupiterSaturnOnly() {
        XCTAssertEqual(SolarSatellites.moons(of: .earth).map(\.id), ["moon"])
        XCTAssertEqual(
            SolarSatellites.moons(of: .jupiter).map(\.id),
            ["io", "europa", "ganymede", "callisto"]
        )
        XCTAssertEqual(SolarSatellites.moons(of: .saturn).map(\.id), ["titan"])
        XCTAssertTrue(SolarSatellites.moons(of: .mars).isEmpty)
        XCTAssertEqual(SolarSatellites.moons.count, 6)
    }

    func testMoonsHiddenWithoutFocus() {
        let scene = builtScene()
        scene.apply(julianDay: 2_461_362.5, showsOrbits: true, rig: OrbitRig(), selected: nil)
        for moon in SolarSatellites.moons {
            let entity = node(scene, named: "moon.\(moon.id)")
            XCTAssertNotNil(entity, moon.id)
            XCTAssertFalse(entity?.isEnabled ?? true, "\(moon.name) 非聚焦态不该显示")
        }
    }

    func testOnlyFocusedParentMoonsShow() {
        let scene = builtScene()
        scene.apply(julianDay: 2_461_362.5, showsOrbits: true, rig: OrbitRig(), selected: .jupiter)
        for moon in SolarSatellites.moons {
            let enabled = node(scene, named: "moon.\(moon.id)")?.isEnabled ?? false
            XCTAssertEqual(enabled, moon.parent == .jupiter, moon.name)
        }
    }

    func testMoonsHiddenDuringTrueScaleNarrative() {
        let scene = builtScene()
        scene.apply(
            julianDay: 2_461_362.5, showsOrbits: true, rig: OrbitRig(),
            selected: .earth, trueScale: true
        )
        XCTAssertFalse(node(scene, named: "moon.moon")?.isEnabled ?? true)
    }

    func testMoonOrbitsMoveWithRealPeriods() {
        let io = SolarSatellites.moons(of: .jupiter)[0]
        let jd = 2_461_362.5
        let a = SolarSatellites.position(for: io, julianDay: jd)
        let b = SolarSatellites.position(for: io, julianDay: jd + io.orbitalPeriodDays / 2)
        XCTAssertGreaterThan(simd_distance(a, b), SolarSatellites.orbitDisplayRadius(for: io), "半周期应到轨道对面")
        let c = SolarSatellites.position(for: io, julianDay: jd + io.orbitalPeriodDays)
        XCTAssertEqual(simd_distance(a, c), 0, accuracy: 0.001, "整周期回到原位")
    }

    func testBeltsAreSingleMergedEntities() {
        let scene = builtScene()
        for name in ["belt.asteroid", "belt.kuiper"] {
            guard let belt = node(scene, named: name) else {
                return XCTFail("没找到 \(name)")
            }
            XCTAssertTrue(belt.children.isEmpty, "带必须是单实体合并网格，不是一堆子实体")
            XCTAssertNotNil(belt.components[ModelComponent.self])
        }
    }

    func testBeltParticlesAreDeterministic() {
        let a = SolarBelts.asteroidParticles
        let b = SolarBelts.asteroidParticles
        XCTAssertEqual(a, b, "同种子必须同位置，截图与预算才可复现")
        XCTAssertEqual(a.count, SolarBelts.asteroidCount)
        XCTAssertEqual(SolarBelts.kuiperParticles.count, SolarBelts.kuiperCount)
    }

    func testBudgetStaysWithinLimits() {
        let scene = builtScene()
        scene.apply(julianDay: 2_461_362.5, showsOrbits: true, rig: OrbitRig(), selected: .jupiter)
        XCTAssertLessThanOrEqual(scene.entityCount, 60, "实体超预算")
        XCTAssertLessThanOrEqual(scene.triangleEstimate, 20_000, "三角形超预算")
        XCTAssertLessThanOrEqual(scene.modelEntityCount, 40, "draw call 超预算")
    }

    func testBudgetWorstCaseAllMoonsBuilt() {
        let scene = builtScene()
        // 最坏情形：木星聚焦（4 卫星）+ 两条带 + 全部轨道。
        scene.apply(julianDay: 2_461_362.5, showsOrbits: true, rig: OrbitRig(), selected: .jupiter)
        let triangles = scene.triangleEstimate
        XCTAssertGreaterThan(triangles, 0)
        XCTAssertLessThanOrEqual(triangles, 20_000)
    }
}