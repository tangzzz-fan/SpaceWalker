import XCTest

@testable import SpaceWalker

@MainActor
final class SkyAttentionCandidatesTests: XCTestCase {
    private func builtScene() throws -> SkyScene {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        let scene = SkyScene()
        scene.build(catalog: catalog)
        return scene
    }

    private func center(_ key: String, in scene: SkyScene) throws -> SIMD3<Float> {
        try XCTUnwrap(scene.constellationShapes.first { $0.key == key }?.center, "缺少 \(key) 轮廓")
    }

    /// 猎户座中心必然落在参宿里。星座与星官同槽时星座必须赢——
    /// 否则轮廓永远不亮，用户看到的就是「指着猎户座没反应」。
    func testConstellationOutranksAsterism() throws {
        let scene = try builtScene()
        let candidates = scene.candidates(along: try center("Ori", in: scene))

        XCTAssertEqual(candidates.constellation?.abbreviation, "Ori")
        XCTAssertNotNil(candidates.asterism, "前提：猎户座中心确实落在某个星官里")

        let attention = candidates.forAttention(
            cultureEnabled: true,
            showsConstellations: true,
            showsPatterns: false
        )
        XCTAssertEqual(attention.constellation, "Ori")
        XCTAssertNil(attention.asterism, "星官不该与星座争同一片天")
    }

    /// 关掉星座层，星官接管——这是星官卡该出现的场合。
    func testAsterismTakesOverWhenConstellationLayerOff() throws {
        let scene = try builtScene()
        let candidates = scene.candidates(along: try center("Ori", in: scene))

        let attention = candidates.forAttention(
            cultureEnabled: true,
            showsConstellations: false,
            showsPatterns: false
        )
        XCTAssertNil(attention.constellation)
        XCTAssertNotNil(attention.asterism)
    }

    func testNoAsterismWhenCultureOff() throws {
        let scene = try builtScene()
        let candidates = scene.candidates(along: try center("Ori", in: scene))

        let attention = candidates.forAttention(
            cultureEnabled: false,
            showsConstellations: false,
            showsPatterns: false
        )
        XCTAssertNil(attention.asterism)
    }

    /// 星座卡靠这条回指星官，信息不因优先级丢掉。
    func testOrionCarriesItsAsterisms() throws {
        let scene = try builtScene()
        let names = scene.asterisms(in: "Ori").map(\.name)
        XCTAssertTrue(names.contains("参宿"), "猎户座里应当有参宿，实际：\(names)")
    }

    /// 轮廓顶点必须算在区域内。射线法对边界点的归属不稳定，没有边界容差时
    /// 「对准轮廓上的亮星」会判成外面——猎户座 9 颗成员星只认 3 颗，天鹅座 5 颗只认 1 颗。
    func testOutlineVerticesAreInside() throws {
        let scene = try builtScene()
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        var byName: [String: Star] = [:]
        for star in catalog.stars where !star.name.isEmpty {
            if let existing = byName[star.name], existing.magnitude <= star.magnitude { continue }
            byName[star.name] = star
        }

        var misses: [String] = []
        for constellation in Constellations.all {
            let vertices = constellation.outline.isEmpty
                ? constellation.outlines.flatMap { $0 }
                : constellation.outline
            guard !vertices.isEmpty,
                  let shape = scene.constellationShapes.first(where: { $0.key == constellation.abbreviation })
            else { continue }
            for name in vertices {
                guard let star = byName[name] else { continue }
                if !shape.contains(SkyPicker.direction(for: star)) {
                    misses.append("\(constellation.abbreviation):\(name)")
                }
            }
        }
        XCTAssertTrue(misses.isEmpty, "轮廓顶点被判在区域外：\(misses.prefix(8))")
    }

    /// 索引与渲染网格分开建：星表为空时索引也该是空数组而不是「没建过」。
    func testIndexBuiltEvenWithoutCatalog() {
        let scene = SkyScene()
        scene.buildAsterisms(from: [])
        XCTAssertTrue(scene.asterismFields.isEmpty)
    }
}
