import XCTest
import simd

@testable import SpaceWalker

@MainActor
final class SkyEphemerisTests: XCTestCase {
    private let jd = 2_461_362.5

    private func builtScene() throws -> SkyScene {
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        let scene = SkyScene()
        scene.build(catalog: catalog)
        scene.viewSize = CGSize(width: 390, height: 844)
        scene.buildBodies(julianDay: jd)
        return scene
    }

    func testSevenBodiesBuiltWithEphemerisPositions() throws {
        let scene = try builtScene()
        XCTAssertEqual(scene.bodyNodes.count, 7)
        XCTAssertEqual(scene.starCount, 2996, "天体不进星表统计")
        for node in scene.bodyNodes {
            let coordinate = try XCTUnwrap(Ephemeris.equatorial(of: node.body, julianDay: jd))
            XCTAssertEqual(node.star.rightAscensionHours, coordinate.raHours, accuracy: 1e-9)
            XCTAssertEqual(node.star.declinationDegrees, coordinate.decDegrees, accuracy: 1e-9)
            XCTAssertEqual(
                simd_length(node.entity.position),
                SkyScene.bodySphereRadius,
                accuracy: 0.001
            )
        }
    }

    func testSameBodySameCoordinatesInSkyAndSolar() throws {
        for body in [EphemerisBody.mercury, .venus, .mars, .jupiter, .saturn, .sun, .moon] {
            let star = try XCTUnwrap(SkyBodies.star(for: body, julianDay: jd))
            let coordinate = try XCTUnwrap(Ephemeris.equatorial(of: body, julianDay: jd))
            XCTAssertEqual(star.rightAscensionHours, coordinate.raHours, accuracy: 1e-9, "\(body)")
            XCTAssertEqual(star.declinationDegrees, coordinate.decDegrees, accuracy: 1e-9, "\(body)")
            let skyDirection = SkyPicker.direction(for: star)
            let solarDirection = StarField.direction(
                rightAscensionHours: coordinate.raHours,
                declinationDegrees: coordinate.decDegrees
            )
            XCTAssertEqual(simd_dot(skyDirection, solarDirection), 1, accuracy: 1e-5, "\(body)")
        }
    }

    func testBodiesMoveWithDate() throws {
        let scene = try builtScene()
        let before = try XCTUnwrap(scene.bodyNodes.first { $0.body == .moon }).star
        scene.updateBodies(julianDay: jd + 7)
        let after = try XCTUnwrap(scene.bodyNodes.first { $0.body == .moon }).star
        XCTAssertGreaterThan(
            SkyPicker.offsetDegrees(SkyPicker.direction(for: before), SkyPicker.direction(for: after)),
            60,
            "月球 7 天应走过约四分之一天球"
        )
    }

    func testCrosshairSelectsPlanetLikeAStar() throws {
        let scene = try builtScene()
        let venus = try XCTUnwrap(scene.bodyNodes.first { $0.body == .venus }).star
        let direction = SkyPicker.direction(for: venus)
        let candidates = scene.candidates(along: direction)
        XCTAssertEqual(candidates.star?.name, "金星")
        scene.aim(at: direction)
        XCTAssertEqual(scene.pickAtCenter()?.name, "金星", "对准后准星应选中金星")
    }

    func testPlanetBeatsNearbyBackgroundStar() throws {
        let scene = try builtScene()
        let jupiter = try XCTUnwrap(scene.bodyNodes.first { $0.body == .jupiter }).star
        let direction = SkyPicker.direction(for: jupiter)
        let hit = scene.candidates(along: direction).star
        XCTAssertEqual(hit?.name, "木星")
    }

    func testBodyLookupRoundTrip() throws {
        for body in SkyBodies.bodies {
            let star = try XCTUnwrap(SkyBodies.star(for: body, julianDay: jd))
            XCTAssertEqual(SkyBodies.body(for: star), body)
            XCTAssertTrue(star.isSelectable)
        }
        let catalog = try XCTUnwrap(StarCatalog.loadFromBundle(.main))
        let named = try XCTUnwrap(catalog.stars.first { $0.isNamed })
        XCTAssertNil(SkyBodies.body(for: named), "恒星不能被认成天体")
    }

    func testDistanceLineOnlyForStarsWithDistance() throws {
        let star = Star(
            rightAscensionHours: 0,
            declinationDegrees: 0,
            magnitude: 1,
            colorIndex: 0,
            name: "Test",
            constellation: "TST",
            distanceLightYears: 8.6
        )
        let line = try XCTUnwrap(SkyBodies.distanceLine(for: star))
        XCTAssertTrue(line.contains("8.6 光年"), line)
        XCTAssertTrue(line.contains("这束光出发于"), line)

        var noDistance = star
        noDistance.distanceLightYears = nil
        XCTAssertNil(SkyBodies.distanceLine(for: noDistance))

        let planet = try XCTUnwrap(SkyBodies.star(for: .venus, julianDay: jd))
        XCTAssertNil(SkyBodies.distanceLine(for: planet), "行星不显示光年行")
    }

    func testDescendFromPlanetCardFocusesThatPlanetNow() throws {
        var state = AppState()
        let reducer = makeAppReducer()
        reducer(&state, .chrome(.select(.body(.jupiter))))
        reducer(&state, .space(.scrub(days: 120)))
        reducer(&state, .descend(.solar))
        XCTAssertEqual(state.route, .solar)
        XCTAssertEqual(state.space.selected, .jupiter)
        XCTAssertEqual(state.space.days, 0, "聚焦此刻位置")
        XCTAssertTrue(state.space.isPaused)
    }

    func testDescendWithoutPlanetSelectionKeepsSolarTime() throws {
        var state = AppState()
        let reducer = makeAppReducer()
        reducer(&state, .space(.scrub(days: 120)))
        reducer(&state, .descend(.solar))
        XCTAssertEqual(state.route, .solar)
        XCTAssertNil(state.space.selected)
        XCTAssertEqual(state.space.days, 120)
        XCTAssertFalse(state.space.isPaused)
    }

    func testMoonGlyphTerminatorFollowsPhase() {
        func litArea(_ mesh: StarMeshData) -> Float {
            var area: Float = 0
            for triangle in stride(from: 0, to: mesh.indices.count, by: 3) {
                let a = mesh.positions[Int(mesh.indices[triangle])]
                let b = mesh.positions[Int(mesh.indices[triangle + 1])]
                let c = mesh.positions[Int(mesh.indices[triangle + 2])]
                area += abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) / 2
            }
            return area
        }

        let waxing = MoonPhase(illuminatedFraction: 0.25, waxing: true, ageDays: 7)
        let waning = MoonPhase(illuminatedFraction: 0.25, waxing: false, ageDays: 22)
        let full = MoonPhase(illuminatedFraction: 1, waxing: true, ageDays: 15)
        let newMoon = MoonPhase(illuminatedFraction: 0, waxing: true, ageDays: 0)

        let waxingMesh = MoonPhaseGlyph.mesh(phase: waxing, radius: 1, segments: 28)
        let waningMesh = MoonPhaseGlyph.mesh(phase: waning, radius: 1, segments: 28)
        let fullMesh = MoonPhaseGlyph.mesh(phase: full, radius: 1, segments: 28)
        let newMesh = MoonPhaseGlyph.mesh(phase: newMoon, radius: 1, segments: 28)

        let waxingLit = waxingMesh.positions.filter { $0.x > 0.01 }.count
        let waningLit = waningMesh.positions.filter { $0.x < -0.01 }.count
        XCTAssertGreaterThan(waxingLit, 0, "渐盈亮面在右")
        XCTAssertGreaterThan(waningLit, 0, "渐亏亮面在左")

        let maxX = fullMesh.positions.map(\.x).max() ?? 0
        let minX = fullMesh.positions.map(\.x).min() ?? 0
        XCTAssertEqual(maxX, 1, accuracy: 0.001, "满月两侧都亮")
        XCTAssertEqual(minX, -1, accuracy: 0.001)

        XCTAssertEqual(litArea(newMesh), 0, accuracy: 0.001, "新月无亮面")
        XCTAssertEqual(litArea(fullMesh), Float.pi, accuracy: 0.02, "满月整个圆面")
        let crescentArea = litArea(waxingMesh)
        XCTAssertGreaterThan(crescentArea, 0.3)
        XCTAssertLessThan(crescentArea, litArea(fullMesh) / 2, "蛾眉月亮面小于半圆")
        XCTAssertEqual(litArea(waningMesh), crescentArea, accuracy: 0.001, "盈亏面积对称")
    }

    func testSolarBridgeMappingCoversVisiblePlanets() {
        XCTAssertEqual(SkyBodies.solarBodyID(for: .sun), .sun)
        XCTAssertEqual(SkyBodies.solarBodyID(for: .mercury), .mercury)
        XCTAssertEqual(SkyBodies.solarBodyID(for: .venus), .venus)
        XCTAssertEqual(SkyBodies.solarBodyID(for: .mars), .mars)
        XCTAssertEqual(SkyBodies.solarBodyID(for: .jupiter), .jupiter)
        XCTAssertEqual(SkyBodies.solarBodyID(for: .saturn), .saturn)
        XCTAssertNil(SkyBodies.solarBodyID(for: .moon))
        XCTAssertNil(SkyBodies.solarBodyID(for: .earth))
    }
}