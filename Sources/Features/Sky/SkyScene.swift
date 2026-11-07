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

        let buckets = StarFieldBuilder.buckets(for: catalog.stars)
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
            root.addChild(entity)
        }

        nodes = catalog.stars
    }

    func attach(_ content: RealityViewCameraContent) {
        self.content = content
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
        let forward = root.orientation.inverse.act(SIMD3<Float>(0, 0, -1))
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)

        for star in SkyPicker.nearest(to: forward, in: nodes) {
            guard let projected = project(star, in: content) else { continue }
            if hypot(projected.x - center.x, projected.y - center.y) <= SkyPicker.crosshairRadius {
                return star
            }
        }
        return nil
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
            let direction = SkyPicker.direction(for: star)
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
        let world = root.convert(position: StarField.position(for: star), to: nil)
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
