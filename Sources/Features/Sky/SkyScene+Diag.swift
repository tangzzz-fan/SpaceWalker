import Foundation
import RealityKit
import simd
import SwiftUI

extension SkyScene {

    // MARK: - 诊断

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
}
