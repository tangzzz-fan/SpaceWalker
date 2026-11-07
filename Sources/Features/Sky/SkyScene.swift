import Foundation
import RealityKit
import simd
import SwiftUI

@MainActor
final class SkyScene {
    static let coordinateSpaceName = "sky"
    static let space = NamedCoordinateSpace.named(coordinateSpaceName)
    static let pickThreshold: CGFloat = 44

    private(set) var root = Entity()
    private var content: RealityViewCameraContent?
    private var nodes: [Star] = []
    private var isBuilt = false
    private(set) var isAttitudeDriven = false

    var starCount: Int {
        nodes.count
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

        for star in nodes {
            let world = root.convert(position: StarField.position(for: star), to: nil)
            guard let projected = content.project(point: world, to: Self.space) else { continue }
            let distance = hypot(projected.x - point.x, projected.y - point.y)
            guard distance <= Self.pickThreshold else { continue }
            if best == nil || distance < best!.distance {
                best = (star, distance)
            }
        }
        return best?.star
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
