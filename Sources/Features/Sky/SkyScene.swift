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
    private(set) var constellationCount = 0
    private var constellationsRequested = true
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
    }

    private func buildConstellations(from stars: [Star]) {
        var positions: [String: SIMD3<Float>] = [:]
        for star in stars where star.isNamed && positions[star.name] == nil {
            positions[star.name] = StarField.position(for: star)
        }
        let segments = Constellations.segments(positions: positions)
        guard !segments.isEmpty,
              let mesh = try? StarFieldBuilder.mesh(
                  StarFieldBuilder.constellation(segments, radius: Self.constellationRadius),
                  name: "constellations"
              )
        else { return }

        let entity = Entity()
        entity.name = "constellations"
        entity.components.set(ModelComponent(
            mesh: mesh,
            materials: [UnlitMaterial(color: uiColor(SIMD3(0.62, 0.72, 0.92), brightness: 0.46))]
        ))
        field.addChild(entity)
        entity.isEnabled = constellationsRequested
        constellationNode = entity
        constellationCount = segments.count
    }

    func setConstellationsVisible(_ visible: Bool) {
        constellationsRequested = visible
        constellationNode?.isEnabled = visible
    }

    static let constellationRadius: Float = 0.032

    func attach(_ content: RealityViewCameraContent) {
        self.content = content
    }

    var viewDirectionInField: SIMD3<Float> {
        (root.orientation * field.orientation).inverse.act(SIMD3<Float>(0, 0, -1))
    }

    func setField(orientation: simd_quatf) {
        field.orientation = orientation
    }

    func setAttitude(_ orientation: simd_quatf) {
        isAttitudeDriven = true
        root.orientation = orientation
    }

    func apply(rig: SkyRig) {
        guard !isAttitudeDriven else { return }
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
