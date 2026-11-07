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
    private var cameraEntity: Entity?
    /// 垂直视场角。默认 60°，和人眼一支手臂看出去的宽度接近。
    private(set) var fieldOfView: Float = SkyScene.defaultFieldOfView
    private var nodes: [Star] = []
    private var field = Entity()
    private var constellationNode: Entity?
    private var silhouetteNode: Entity?
    private(set) var constellationCount = 0
    private var constellationsRequested = true
    private var silhouettesRequested = false
    private var constellationShapes: [OutlineShape] = []
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
    private var patternNode: Entity?
    private var patternMaterial: UnlitMaterial?
    private var patternShapes: [OutlineShape] = []
    private var patternHighlightNode: Entity?
    private var patternHighlightID: String?
    private(set) var patternSegmentCount = 0
    private var patternsRequested = false
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
        buildPatterns()
    }

    private func buildConstellations(from stars: [Star]) {
        var positions: [String: SIMD3<Float>] = [:]
        for star in stars where !star.key.isEmpty && positions[star.key] == nil {
            positions[star.key] = StarField.position(for: star)
        }
        // 连线一律从 all 取：它已经把 detailedLines 注入进去了。
        // 直接读 primary 会拿到手工那 3–10 段，人马座就只剩壶身。
        let primaryKeys = Set(Constellations.primary.map(\.abbreviation))
        let primarySegments = Constellations.segments(
            positions: positions,
            in: Constellations.all.filter { primaryKeys.contains($0.abbreviation) }
        )
        let extendedSegments = Constellations.segments(
            positions: positions,
            in: Constellations.all.filter { !primaryKeys.contains($0.abbreviation) }
        )
        guard !primarySegments.isEmpty else { return }

        let group = Entity()
        group.name = "constellationGroup"
        field.addChild(group)

        if let sticks = try? StarFieldBuilder.mesh(
            StarFieldBuilder.constellation(primarySegments, radius: Self.constellationRadius),
            name: "constellations"
        ) {
            let stickNode = Entity()
            stickNode.name = "constellation.lines"
            stickNode.components.set(ModelComponent(
                mesh: sticks,
                materials: [UnlitMaterial(color: uiColor(SIMD3(0.62, 0.72, 0.92), brightness: 0.46))]
            ))
            group.addChild(stickNode)
        }

        // 补全的 57 座只画骨架，亮度压到手工座的三分之一：走到那儿看得见
        // 「这里有个星座」，但不会把默认视野铺满。半径也小一档，避免叠线。
        if let faint = try? StarFieldBuilder.mesh(
            StarFieldBuilder.constellation(
                extendedSegments,
                radius: Self.constellationRadius * 0.62
            ),
            name: "constellations.minor"
        ) {
            let stickNode = Entity()
            stickNode.name = "constellation.lines.minor"
            stickNode.components.set(ModelComponent(
                mesh: faint,
                materials: [UnlitMaterial(color: uiColor(SIMD3(0.62, 0.72, 0.92), brightness: 0.2))]
            ))
            group.addChild(stickNode)
        }

        buildSilhouettes(positions: positions)

        group.isEnabled = constellationsRequested
        constellationNode = group
        constellationCount = primarySegments.count + extendedSegments.count
    }

    /// 画填充用的闭合环：只认手工轮廓与美术图形。
    /// 没有显式轮廓的星座不画填充——凸包会把凹处填平，人马座的茶壶会变成一块饼，
    /// 形状一丢，人就认不出像什么了。骨架线本身已经够读。
    static func fillRings(
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
        return []
    }

    /// 判定用的闭合环：手工轮廓优先，缺了就退回成员星凸包。
    /// 凸包粗糙但一定闭合，用来回答「你正对着哪个星座」，不参与绘制。
    static func hitRings(
        for constellation: Constellation,
        positions: [String: SIMD3<Float>]
    ) -> [[SIMD3<Float>]] {
        let drawn = fillRings(for: constellation, positions: positions)
        if !drawn.isEmpty { return drawn }
        let names = Array(Set(constellation.lines.flatMap { [$0.first, $0.second] }))
        let points = names.compactMap { positions[$0] }
        guard points.count >= 3 else { return [] }
        return [StarFieldBuilder.hullRing(points)]
    }

    private func buildSilhouettes(positions: [String: SIMD3<Float>]) {
        var fillMesh = StarMeshData(positions: [], normals: [], indices: [])
        var outlineSegments: [(SIMD3<Float>, SIMD3<Float>)] = []
        var shapes: [OutlineShape] = []

        for constellation in Constellations.all {
            // 判定环覆盖 88 座（凸包兜底），绘制环只覆盖手工画过轮廓的那批。
            if let shape = ConstellationFigureBuilder.shape(
                key: constellation.abbreviation,
                rings: Self.hitRings(for: constellation, positions: positions)
            ) {
                shapes.append(shape)
            }
            let drawn = Self.fillRings(for: constellation, positions: positions)
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
        var best: (key: String, dot: Float)?
        for shape in constellationShapes where shape.contains(direction) {
            let dot = simd_dot(simd_normalize(direction), shape.center)
            if best == nil || dot > best!.dot {
                best = (shape.key, dot)
            }
        }
        guard let best else { return nil }
        return Constellations.all.first { $0.abbreviation == best.key }
    }

    func constellationAtCenter() -> Constellation? {
        constellation(at: viewDirectionInField)
    }

    /// 临时点亮一个星座：即使总开关关着，也让用户看见自己指着的那几条线。
    /// 亮的是骨架本身，不是外轮廓——用户问「为什么是它」，
    /// 答案应该落在「这几颗星连成这个形状」上，而不是一个把它们包起来的多边形。
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
        let segments = constellation.lines.compactMap { line -> (SIMD3<Float>, SIMD3<Float>)? in
            guard let a = positions[line.first], let b = positions[line.second] else { return nil }
            let radius = Self.constellationHighlightRadius
            return (simd_normalize(a) * radius, simd_normalize(b) * radius)
        }
        SessionLog.append("sky.highlight id=\(abbreviation) lines=\(constellation.lines.count) pos=\(positions.count) segs=\(segments.count)")
        guard !segments.isEmpty,
              let mesh = try? StarFieldBuilder.mesh(
                  StarFieldBuilder.constellation(segments, radius: 0.125),
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

    // MARK: - 星群

    private func buildPatterns() {
        let positions = constellationPositions
        guard !positions.isEmpty else { return }

        var segments: [(SIMD3<Float>, SIMD3<Float>)] = []
        var shapes: [OutlineShape] = []
        for pattern in SkyPatternCatalog.all {
            let drawn = SkyPatternGeometry.segments(
                for: pattern,
                positions: positions,
                radius: Self.patternRadius3D
            )
            guard !drawn.isEmpty else { continue }
            segments.append(contentsOf: drawn)
            if let ring = SkyPatternGeometry.ring(for: pattern, positions: positions),
               let shape = ConstellationFigureBuilder.shape(key: pattern.id, rings: [ring]) {
                shapes.append(shape)
            }
        }
        patternShapes = shapes
        patternSegmentCount = segments.count

        guard !segments.isEmpty,
              let mesh = try? StarFieldBuilder.mesh(
                  StarFieldBuilder.constellation(segments, radius: Self.patternTubeRadius),
                  name: "patterns"
              )
        else { return }

        let material = UnlitMaterial(
            color: uiColor(Self.patternColor, brightness: Self.patternBaseBrightness)
        )
        let node = Entity()
        node.name = "pattern.lines"
        node.components.set(ModelComponent(mesh: mesh, materials: [material]))
        node.isEnabled = patternsRequested
        field.addChild(node)
        patternNode = node
        patternMaterial = material
    }

    func setPatternsVisible(_ visible: Bool) {
        patternsRequested = visible
        patternNode?.isEnabled = visible
        patternHighlightNode?.isEnabled = visible
    }

    /// 点环方向落在哪个闭合星群内部。命中多个时取距离中心最近的一个。
    func pattern(at direction: SIMD3<Float>) -> SkyPattern? {
        var best: (key: String, dot: Float)?
        for shape in patternShapes where shape.contains(direction) {
            let dot = simd_dot(simd_normalize(direction), shape.center)
            if best == nil || dot > best!.dot {
                best = (shape.key, dot)
            }
        }
        guard let best else { return nil }
        return SkyPatternCatalog.pattern(id: best.key)
    }

    func patternAtCenter() -> SkyPattern? {
        pattern(at: viewDirectionInField)
    }

    /// 星群几何中心方向，用于对准与调试。
    func direction(forPattern id: String) -> SIMD3<Float>? {
        guard let pattern = SkyPatternCatalog.pattern(id: id) else { return nil }
        let points = pattern.anchors.compactMap { constellationPositions[$0] }
        guard !points.isEmpty else { return nil }
        var sum = SIMD3<Float>(0, 0, 0)
        for point in points {
            sum += simd_normalize(point)
        }
        guard simd_length(sum) > 0.001 else { return nil }
        return simd_normalize(sum)
    }

    /// 临时点亮一条星群，其余星群压暗——和星官高亮同一套语言。
    func highlightPattern(_ id: String?) {
        guard id != patternHighlightID else { return }
        patternHighlightID = id
        patternHighlightNode?.removeFromParent()
        patternHighlightNode = nil
        patternMaterial?.color.tint = id == nil
            ? uiColor(Self.patternColor, brightness: Self.patternBaseBrightness)
            : uiColor(Self.patternColor, brightness: Self.patternDimBrightness)

        guard let id,
              let pattern = SkyPatternCatalog.pattern(id: id),
              !constellationPositions.isEmpty
        else { return }

        let segments = SkyPatternGeometry.segments(
            for: pattern,
            positions: constellationPositions,
            radius: Self.patternHighlightRadius3D
        )
        guard !segments.isEmpty,
              let mesh = try? StarFieldBuilder.mesh(
                  StarFieldBuilder.constellation(segments, radius: Self.patternHighlightTubeRadius),
                  name: "pattern.focus"
              )
        else { return }

        let node = Entity()
        node.name = "pattern.focus"
        node.components.set(ModelComponent(
            mesh: mesh,
            materials: [UnlitMaterial(
                color: uiColor(Self.patternColor, brightness: Self.patternHighlightBrightness)
            )]
        ))
        node.isEnabled = true
        field.addChild(node)
        patternHighlightNode = node
    }

    static let patternColor = SIMD3<Float>(0.80, 0.66, 0.98)
    static let patternTubeRadius: Float = 0.018
    static let patternHighlightTubeRadius: Float = 0.024
    static let patternRadius3D: Float = 49.0
    static let patternHighlightRadius3D: Float = 48.8
    static let patternBaseBrightness: Float = 0.60
    static let patternDimBrightness: Float = 0.18
    static let patternHighlightBrightness: Float = 1.0

    static let asterismColor = SIMD3<Float>(0.88, 0.76, 0.52)
    static let asterismRadius: Float = 0.026
    static let asterismHighlightRadius: Float = 0.03
    static let asterismRadius3D: Float = 49.4
    static let asterismHighlightRadius3D: Float = 49.2
    static let asterismBaseBrightness: Float = 0.52
    static let asterismDimBrightness: Float = 0.16
    static let asterismHighlightBrightness: Float = 0.98
    /// 视场范围：16° 能把人马座整个塞满屏幕，95° 用来纵览银河。
    static let defaultFieldOfView: Float = 60
    static let minFieldOfView: Float = 16
    static let maxFieldOfView: Float = 95

    /// 线的世界半径。0.032 在半径 50 的球面上只占 0.037°，60° 视场里约 0.5pt，
    /// 比星点细二十倍——这才是「骨架摆着却看不出来」的真实原因，不是数据不够。
    static let constellationRadius: Float = 0.088
    static let constellationFillRadius: Float = 51.4
    static let constellationOutlineRadius: Float = 50.6
    /// 高亮层要落在星座线（半径 50）的内侧才不会被原线挡住。
    static let constellationHighlightRadius: Float = 49.6

    func attach(_ content: RealityViewCameraContent) {
        self.content = content
        installCamera()
    }

    /// 自建透视相机，为的是能改视场角。
    ///
    /// `content.camera = .virtual` 用的是系统默认 FOV，外部改不了；人马座跨 35°、
    /// 天鹅十字 30°，而竖屏默认视场只有三十几度，永远差一点装不下。
    /// 相机挂在 content 根上（不挂 field），因为星空转、相机不转。
    private func installCamera() {
        guard let content, cameraEntity == nil else { return }
        let entity = Entity()
        entity.name = "sky.camera"
        entity.components.set(PerspectiveCameraComponent(
            near: 0.05,
            far: 500,
            fieldOfViewInDegrees: fieldOfView
        ))
        content.add(entity)
        cameraEntity = entity
    }

    func setFieldOfView(_ degrees: Float) {
        let clamped = min(Self.maxFieldOfView, max(Self.minFieldOfView, degrees))
        guard abs(clamped - fieldOfView) > 0.05 else { return }
        fieldOfView = clamped
        guard let cameraEntity,
              var camera = cameraEntity.components[PerspectiveCameraComponent.self]
        else { return }
        camera.fieldOfViewInDegrees = clamped
        cameraEntity.components.set(camera)
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
        // 真机上姿态回调是 67Hz 直写，会在一帧内把 aim 覆盖掉。
        // 039 修过 apply(rig:) 的同款问题，这里漏了同一个守卫。
        guard !aimLocked else { return }
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

    /// 顶栏「当前天区」的答案。优先级与点环识别一致：星座轮廓 > 星群 > 最近成员星，
    /// 三档共用同一份轮廓数据，顶栏与标识卡才不会各说各话。
    ///
    /// 兜底不加角距门槛：6 等星表把全天盖满，实测任意方向到最近成员星最远 6.9°
    /// （p50 1.8°、p99 4.9°），加了也永远不会触发。
    func currentRegion() -> SkyRegion? {
        let direction = viewDirectionInField
        if let constellation = constellation(at: direction) {
            return ConstellationInfo
                .region(for: constellation.abbreviation, in: nodes)
                .map(SkyRegion.constellation)
        }
        if let pattern = pattern(at: direction) {
            return .pattern(pattern)
        }
        return ConstellationInfo
            .nearest(to: direction, in: nodes)
            .map(SkyRegion.constellation)
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

    /// 场景预算：实体数与各层线段数。掉帧时先分清是「节点太多」还是「像素太多」。
    func budget() -> String {
        var entities = 0
        var meshes = 0
        func walk(_ node: Entity) {
            entities += 1
            if node.components[ModelComponent.self] != nil { meshes += 1 }
            for child in node.children { walk(child) }
        }
        walk(root)
        return String(
            format: "sky.budget entities=%d meshes=%d constellation=%d asterism=%d pattern=%d",
            entities,
            meshes,
            constellationCount,
            asterismSegmentCount,
            patternSegmentCount
        )
    }

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
