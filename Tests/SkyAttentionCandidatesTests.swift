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

    /// 索引与渲染网格分开建：星表为空时索引也该是空数组而不是「没建过」。
    func testIndexBuiltEvenWithoutCatalog() {
        let scene = SkyScene()
        scene.buildAsterisms(from: [])
        XCTAssertTrue(scene.asterismFields.isEmpty)
    }
}
