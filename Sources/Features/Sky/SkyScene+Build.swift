import Foundation
import RealityKit
import simd
import SwiftUI

extension SkyScene {

    // MARK: - 构建

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

    func buildConstellations(from stars: [Star]) {
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

    func buildSilhouettes(positions: [String: SIMD3<Float>]) {
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


    func buildAsterisms(from stars: [Star]) {
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

    func asterismSegments(
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


    func buildPatterns() {
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

}
