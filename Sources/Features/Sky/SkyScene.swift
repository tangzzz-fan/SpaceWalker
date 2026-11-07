import Foundation
import RealityKit
import simd
import SwiftUI

@MainActor
final class SkyScene {
    static let coordinateSpaceName = "sky"
    static let space = NamedCoordinateSpace.named(coordinateSpaceName)

    private(set) var root = Entity()
    private var content: RealityViewCameraContent?
    private var nodes: [Star] = []
    private var field = Entity()
    private var constellationNode: Entity?
    private var silhouetteNode: Entity?
    private(set) var constellationCount = 0
    private var constellationsRequested = true
    private var silhouettesRequested = false
    private var constellationShapes: [ConstellationOutlineShape] = []
    private var constellationHighlightNode: Entity?
    private var constellationHighlightID: String?
    private var constellationPositions: [String: SIMD3<Float>] = [:]
    private var asterismNode: Entity?
    private var asterismMaterial: UnlitMaterial?
    private var asterismHighlightNode: Entity?
    private var asterismHighlightID: String?
    private var starsByHIP: [Int: Star] = [:]
    private(set) var asterismSegmentCount = 0
    private(set) var asterismGroupCount = 0
    private var asterismsRequested = false
    private var aimLocked = false
    private var isBuilt = false
    private var viewSize: CGSize = .zero
    private(set) var isAttitudeDriven = false

    var starCount: Int {
        nodes.count
    }

    var selectableCount: Int {
        nodes.filter(\.isSelectable).count
    }

    var isReady: Bool {
        content != nil && !nodes.isEmpty && viewSize.width > 0
    }

    func resize(_ size: CGSize) {
        viewSize = size
    }

    func build(catalog: StarCatalog) {
        guard !isBuilt else { return }
        isBuilt = true
        root.name = "sky"
        field.name = "field"
        root.addChild(field)

        let buckets = StarFieldBuilder.selectableBuckets(for: catalog.stars)
        for (index, bucket) in buckets.enumerated() where !bucket.isEmpty {
            guard let mesh = try? StarFieldBuilder.mesh(
                StarFieldBuilder.chunk(for: bucket),
                name: "stars.bucket.\(index)"
            ) else { continue }

            let averageColor = bucket
                .map { StarField.color(forColorIndex: $0.colorIndex) }
                .reduce(SIMD3<Float>(0, 0, 0), +) / Float(bucket.count)
            let averageMagnitude = bucket.map(\.magnitude).reduce(0, +) / Double(bucket.count)
            let brightness = StarField.brightness(for: averageMagnitude)

            let entity = Entity()
            entity.name = "bucket.\(index)"
            entity.components.set(ModelComponent(
                mesh: mesh,
                materials: [UnlitMaterial(color: uiColor(averageColor, brightness: brightness))]
            ))
            field.addChild(entity)
        }

        let background = StarFieldBuilder.backgroundStars(for: catalog.stars)
        if !background.isEmpty,
           let mesh = try? StarFieldBuilder.mesh(
               StarFieldBuilder.chunk(for: background, scale: 0.62),
               name: "stars.background"
           ) {
            let averageColor = background
                .map { StarField.color(forColorIndex: $0.colorIndex) }
                .reduce(SIMD3<Float>(0, 0, 0), +) / Float(background.count)
            let entity = Entity()
            entity.name = "background"
            entity.components.set(ModelComponent(
                mesh: mesh,
                materials: [UnlitMaterial(color: uiColor(averageColor, brightness: StarField.backgroundBrightness))]
            ))
            field.addChild(entity)
        }

        nodes = catalog.stars
        buildConstellations(from: catalog.stars)
        buildAsterisms(from: catalog.stars)
    }

    private func buildConstellations(from stars: [Star]) {
        var positions: [String: SIMD3<Float>] = [:]
        for star in stars where star.isNamed && positions[star.name] == nil {
            positions[star.name] = StarField.position(for: star)
        }
        let segments = Constellations.segments(positions: positions)
        guard !segments.isEmpty,
              let sticks = try? StarFieldBuilder.mesh(
                  StarFieldBuilder.constellation(segments, radius: Self.constellationRadius),
                  name: "constellations"
              )
        else { return }

        let group = Entity()
        group.name = "constellationGroup"
        field.addChild(group)

        let stickNode = Entity()
        stickNode.name = "constellation.lines"
        stickNode.components.set(ModelComponent(
            mesh: sticks,
            materials: [UnlitMaterial(color: uiColor(SIMD3(0.62, 0.72, 0.92), brightness: 0.46))]
        ))
        group.addChild(stickNode)

        buildSilhouettes(positions: positions)

        group.isEnabled = constellationsRequested
        constellationNode = group
        constellationCount = segments.count
    }

    /// 每个星座画出的闭合环：优先手工星点轮廓，其次美术图形，最后凸包兜底。
    static func rings(
        for constellation: Constellation,
        positions: [String: SIMD3<Float>]
    ) -> [[SIMD3<Float>]] {
        if let figure = ConstellationFigures.all[constellation.abbreviation] {
            return ConstellationFigureBuilder.rings(figure, positions: positions)
        }
        if !constellation.outlines.isEmpty,
           constellation.outlines.allSatisfy({ ring in ring.allSatisfy { positions[$0] != nil } }) {
            return constellation.outlines.map { $0.compactMap { positions[$0] } }
        }
        if constellation.outline.count >= 3,
           constellation.outline.allSatisfy({ positions[$0] != nil }) {
            return [constellation.outline.compactMap { positions[$0] }]
        }
        let names = Array(Set(constellation.lines.flatMap { [$0.first, $0.second] }))
        let points = names.compactMap { positions[$0] }
        guard points.count >= 3 else { return [] }
        return [StarFieldBuilder.hullRing(points)]
    }

    private func buildSilhouettes(positions: [String: SIMD3<Float>]) {
        var fillMesh = StarMeshData(positions: [], normals: [], indices: [])
        var outlineSegments: [(SIMD3<Float>, SIMD3<Float>)] = []
        var shapes: [ConstellationOutlineShape] = []

        for constellation in Constellations.all {
            let drawn = Self.rings(for: constellation, positions: positions)
            guard !drawn.isEmpty else { continue }
            if let shape = ConstellationFigureBuilder.shape(
                abbreviation: constellation.abbreviation,
                rings: drawn
            ) {
                shapes.append(shape)
            }
            for ring in drawn where ring.count >= 3 {
                fillMesh = StarFieldBuilder.merge([
                    fillMesh,
                    StarFieldBuilder.polygon(ring: ring, radius: Self.constellationFillRadius),
                ])

                let vertices = ring.map { simd_normalize($0) * Self.constellationOutlineRadius }
                for index in 0..<vertices.count {
                    outlineSegments.append((vertices[index], vertices[(index + 1) % vertices.count]))
                }
            }
        }

        constellationShapes = shapes
        constellationPositions = positions
        guard !fillMesh.positions.isEmpty, !outlineSegments.isEmpty else { return }

        let group = Entity()
        group.name = "constellation.silhouette"

        if let fill = try? StarFieldBuilder.mesh(fillMesh, name: "constellation.fill") {
            let node = Entity()
            node.name = "constellation.fill"
            node.components.set(ModelComponent(
                mesh: fill,
                materials: [UnlitMaterial(color: uiColor(SIMD3(0.042, 0.062, 0.115), brightness: 1))]
            ))
            group.addChild(node)
        }

        let outlineMesh = StarFieldBuilder.constellation(outlineSegments, radius: 0.011)
        if let outline = try? StarFieldBuilder.mesh(outlineMesh, name: "constellation.outline") {
            let node = Entity()
            node.name = "constellation.outline"
            node.components.set(ModelComponent(
                mesh: outline,
                materials: [UnlitMaterial(color: uiColor(SIMD3(0.40, 0.52, 0.75), brightness: 0.72))]
            ))
            group.addChild(node)
        }
        group.isEnabled = silhouettesRequested
        field.addChild(group)
        silhouetteNode = group
    }

    func setConstellationsVisible(_ visible: Bool) {
        constellationsRequested = visible
        constellationNode?.isEnabled = visible
    }

    func setSilhouettesVisible(_ visible: Bool) {
        silhouettesRequested = visible
        silhouetteNode?.isEnabled = visible
    }

    /// 点环方向落在哪个星座轮廓内。命中多个时取距离中心最近的一个。
    func constellation(at direction: SIMD3<Float>) -> Constellation? {
        var best: (abbreviation: String, dot: Float)?
        for shape in constellationShapes where shape.contains(direction) {
            let dot = simd_dot(simd_normalize(direction), shape.center)
            if best == nil || dot > best!.dot {
                best = (shape.abbreviation, dot)
            }
        }
        guard let best else { return nil }
        return Constellations.all.first { $0.abbreviation == best.abbreviation }
    }

    func constellationAtCenter() -> Constellation? {
        constellation(at: viewDirectionInField)
    }

    /// 某个星座的几何中心方向，用于对准与调试。
    func direction(forConstellation abbreviation: String) -> SIMD3<Float>? {
        guard let constellation = Constellations.all.first(where: { $0.abbreviation == abbreviation })
        else { return nil }
        let names = Set(constellation.lines.flatMap { [$0.first, $0.second] })
        var sum = SIMD3<Float>(0, 0, 0)
        var count = 0
        for name in names {
            guard let position = constellationPositions[name] else { continue }
            sum += simd_normalize(position)
            count += 1
        }
        guard count > 0, simd_length(sum) > 0.001 else { return nil }
        return simd_normalize(sum)
    }

    /// 临时点亮一个星座的轮廓：即使总开关关着，也让用户看见自己指着的那块。
    func highlightConstellation(_ abbreviation: String?) {
        guard abbreviation != constellationHighlightID else { return }
        constellationHighlightID = abbreviation
        constellationHighlightNode?.removeFromParent()
        constellationHighlightNode = nil
        guard let abbreviation,
              let constellation = Constellations.all.first(where: { $0.abbreviation == abbreviation })
        else { return }

        let positions = constellationPositions
        guard !positions.isEmpty else { return }
        let drawn = Self.rings(for: constellation, positions: positions)
        var segments: [(SIMD3<Float>, SIMD3<Float>)] = []
        for ring in drawn where ring.count >= 3 {
            let vertices = ring.map { simd_normalize($0) * Self.constellationHighlightRadius }
            for index in 0..<vertices.count {
                segments.append((vertices[index], vertices[(index + 1) % vertices.count]))
            }
        }
        guard !segments.isEmpty,
              let mesh = try? StarFieldBuilder.mesh(
                  StarFieldBuilder.constellation(segments, radius: 0.026),
                  name: "constellation.focus"
              )
        else { return }

        let node = Entity()
        node.name = "constellation.focus"
        node.components.set(ModelComponent(
            mesh: mesh,
            materials: [UnlitMaterial(color: uiColor(SIMD3(0.66, 0.78, 0.98), brightness: 1))]
        ))
        node.isEnabled = true
        field.addChild(node)
        constellationHighlightNode = node
    }


    private func buildAsterisms(from stars: [Star]) {
        starsByHIP = Dictionary(
            stars.compactMap { star in star.hipparcos.map { ($0, star) } },
            uniquingKeysWith: { first, second in
                first.magnitude <= second.magnitude ? first : second
            }
        )

        var segments: [(SIMD3<Float>, SIMD3<Float>)] = []
        var drawnGroups = 0
        for asterism in AsterismCatalog.all {
            let lines = asterismSegments(for: asterism)
            guard !lines.isEmpty else { continue }
            segments.append(contentsOf: lines)
            drawnGroups += 1
        }
        guard !segments.isEmpty,
              let mesh = try? StarFieldBuilder.mesh(
                  StarFieldBuilder.constellation(segments, radius: Self.asterismRadius),
                  name: "asterisms"
              )
        else { return }

        let material = UnlitMaterial(color: uiColor(Self.asterismColor, brightness: Self.asterismBaseBrightness))
        let node = Entity()
        node.name = "asterism.lines"
        node.components.set(ModelComponent(mesh: mesh, materials: [material]))
        node.isEnabled = asterismsRequested
        field.addChild(node)
        asterismNode = node
        asterismMaterial = material
        asterismSegmentCount = segments.count
        asterismGroupCount = drawnGroups
    }

    private func asterismSegments(
        for asterism: Asterism,
        radius: Float = SkyScene.asterismRadius3D
    ) -> [(SIMD3<Float>, SIMD3<Float>)] {
        var segments: [(SIMD3<Float>, SIMD3<Float>)] = []
        for line in asterism.lines {
            let points = line.compactMap { hip -> SIMD3<Float>? in
                guard let star = starsByHIP[hip] else { return nil }
                return StarField.position(for: star, radius: radius)
            }
            guard points.count >= 2 else { continue }
            for index in 0..<(points.count - 1) {
                segments.append((points[index], points[index + 1]))
            }
        }
        return segments
    }

    func setAsterismsVisible(_ visible: Bool) {
        asterismsRequested = visible
        asterismNode?.isEnabled = visible
        asterismHighlightNode?.isEnabled = visible
    }

    func highlightAsterism(_ asterismID: String?) {
        guard let asterismID,
              let asterism = AsterismCatalog.all.first(where: { $0.id == asterismID })
        else {
            clearAsterismHighlight()
            return
        }
        guard asterismID != asterismHighlightID else { return }
        asterismHighlightID = asterismID
        asterismMaterial?.color.tint = uiColor(Self.asterismColor, brightness: Self.asterismDimBrightness)

        asterismHighlightNode?.removeFromParent()
        asterismHighlightNode = nil

        let segments = asterismSegments(for: asterism, radius: Self.asterismHighlightRadius3D)
        guard !segments.isEmpty,
              let mesh = try? StarFieldBuilder.mesh(
                  StarFieldBuilder.constellation(segments, radius: Self.asterismHighlightRadius),
                  name: "asterism.highlight"
              )
        else { return }

        let node = Entity()
        node.name = "asterism.highlight"
        node.components.set(ModelComponent(
            mesh: mesh,
            materials: [UnlitMaterial(color: uiColor(Self.asterismColor, brightness: Self.asterismHighlightBrightness))]
        ))
        node.isEnabled = asterismsRequested
        field.addChild(node)
        asterismHighlightNode = node
    }

    func clearAsterismHighlight() {
        asterismHighlightID = nil
        asterismMaterial?.color.tint = uiColor(Self.asterismColor, brightness: Self.asterismBaseBrightness)
        asterismHighlightNode?.removeFromParent()
        asterismHighlightNode = nil
    }

    static let asterismColor = SIMD3<Float>(0.88, 0.76, 0.52)
    static let asterismRadius: Float = 0.026
    static let asterismHighlightRadius: Float = 0.03
    static let asterismRadius3D: Float = 49.4
    static let asterismHighlightRadius3D: Float = 49.2
    static let asterismBaseBrightness: Float = 0.52
    static let asterismDimBrightness: Float = 0.16
    static let asterismHighlightBrightness: Float = 0.98
    static let constellationRadius: Float = 0.032
    static let constellationFillRadius: Float = 51.4
    static let constellationOutlineRadius: Float = 50.6
    static let constellationHighlightRadius: Float = 50.4

    func attach(_ content: RealityViewCameraContent) {
        self.content = content
    }

    var viewDirectionInField: SIMD3<Float> {
        (root.orientation * field.orientation).inverse.act(SIMD3<Float>(0, 0, -1))
    }

    func setField(orientation: simd_quatf) {
        field.orientation = orientation
    }

    /// 把视线转到某个方向。定位后要锁住，否则无陀螺仪时 `apply(rig:)`
    /// 会在下一次 RealityView 更新里把朝向拉回拖动状态。
    func aim(at direction: SIMD3<Float>) {
        let length = simd_length(direction)
        guard length > 0.0001 else { return }
        let world = field.orientation.act(direction / length)
        root.orientation = simd_quatf(from: world, to: SIMD3<Float>(0, 0, -1))
        aimLocked = true
    }

    func releaseAim() {
        aimLocked = false
    }

    func setAttitude(_ orientation: simd_quatf) {
        isAttitudeDriven = true
        root.orientation = orientation
    }

    func apply(rig: SkyRig) {
        guard !isAttitudeDriven, !aimLocked else { return }
        root.orientation = rig.orientation
    }

    func pick(at point: CGPoint) -> Star? {
        guard let content else { return nil }
        var best: (star: Star, distance: CGFloat)?

        for star in nodes where star.isSelectable {
            guard let projected = project(star, in: content) else { continue }
            let distance = hypot(projected.x - point.x, projected.y - point.y)
            guard distance <= SkyPicker.crosshairRadius else { continue }
            if best == nil || distance < best!.distance {
                best = (star, distance)
            }
        }
        return best?.star
    }

    func pickAtCenter() -> Star? {
        guard let content, viewSize.width > 0 else { return nil }
        let forward = viewDirectionInField
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)

        for star in SkyPicker.nearest(to: forward, in: nodes) {
            guard let projected = project(star, in: content) else { continue }
            if hypot(projected.x - center.x, projected.y - center.y) <= SkyPicker.crosshairRadius {
                return star
            }
        }
        return nil
    }

    func renderedDirection(of star: Star) -> SIMD3<Float>? {
        let world = field.convert(position: StarField.position(for: star), to: nil)
        let length = simd_length(world)
        guard length > 0.0001 else { return nil }
        return world / length
    }

    func currentRegion() -> ConstellationRegion? {
        ConstellationInfo.nearest(to: viewDirectionInField, in: nodes)
    }

    func guideVector(to star: Star) -> GuideVector? {
        guard let direction = renderedDirection(of: star) else { return nil }
        return SkyGuide.vector(to: direction)
    }

    func aimOffsetDegrees(of star: Star) -> Double {
        guard let direction = renderedDirection(of: star) else { return 180 }
        return SkyPicker.offsetDegrees(direction, Self.screenCenterDirection)
    }

    static let screenCenterDirection = SIMD3<Float>(0, 0, -1)

    func pickDiagnostics(radius: CGFloat = 60) -> String {
        guard let content, viewSize.width > 0 else { return "sky.pickNear not-ready" }
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        var near: [(name: String, distance: CGFloat, magnitude: Double, selectable: Bool)] = []

        for star in nodes {
            guard let projected = project(star, in: content) else { continue }
            let distance = hypot(projected.x - center.x, projected.y - center.y)
            guard distance <= radius else { continue }
            near.append((star.name.isEmpty ? "-" : star.name, distance, star.magnitude, star.isSelectable))
        }

        guard !near.isEmpty else { return "sky.pickNear none" }
        near.sort { $0.distance < $1.distance }
        let top = near.prefix(3).map {
            String(format: "%@ %.1fpt m%.1f %@", $0.name, $0.distance, $0.magnitude, $0.selectable ? "sel" : "bg")
        }
        return "sky.pickNear " + top.joined(separator: " | ")
    }

    func pickRoundtrip() -> String {
        guard let content, viewSize.width > 0 else {
            return "sky.pickProbe skipped=not-ready"
        }
        let saved = root.orientation
        defer { root.orientation = saved }

        let targets = nodes.filter(\.isSelectable)
        var passed = 0
        var failures: [String] = []

        for star in targets {
            let direction = field.orientation.act(SkyPicker.direction(for: star))
            root.orientation = simd_quatf(from: direction, to: SIMD3<Float>(0, 0, -1))
            guard let hit = pickAtCenter() else {
                failures.append("\(star.name):none")
                continue
            }
            if hit == star || SkyPicker.angularDistance(hit, star) < 0.05 {
                passed += 1
            } else {
                failures.append("\(star.name)->\(hit.name)")
            }
        }

        let detail = failures.prefix(5).joined(separator: ",")
        let axis = content.project(point: SIMD3<Float>(0, 0, -StarField.sphereRadius), to: Self.space)
        return String(
            format: "sky.pickProbe ok=%d/%d axis=%.0f,%.0f view=%.0f,%.0f failed=%@",
            passed,
            targets.count,
            axis?.x ?? -1,
            axis?.y ?? -1,
            viewSize.width,
            viewSize.height,
            detail
        )
    }

    private func project(_ star: Star, in content: RealityViewCameraContent) -> CGPoint? {
        let world = field.convert(position: StarField.position(for: star), to: nil)
        return content.project(point: world, to: Self.space)
    }

    private func uiColor(_ rgb: SIMD3<Float>, brightness: Float) -> UIColor {
        UIColor(
            red: CGFloat(rgb.x) * CGFloat(brightness),
            green: CGFloat(rgb.y) * CGFloat(brightness),
            blue: CGFloat(rgb.z) * CGFloat(brightness),
            alpha: 1
        )
    }
}
