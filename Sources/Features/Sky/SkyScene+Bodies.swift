import Foundation
import RealityKit
import simd
import UIKit

extension SkyScene {
    struct BodyNode {
        var body: EphemerisBody
        var entity: Entity
        var star: Star
    }

    var bodyNodes: [BodyNode] {
        get { bodyNodeStorage }
        set { bodyNodeStorage = newValue }
    }

    func buildBodies(julianDay: Double) {
        guard bodyGroup == nil else {
            updateBodies(julianDay: julianDay)
            return
        }
        let group = Entity()
        group.name = "bodies"
        field.addChild(group)
        bodyGroup = group

        for body in SkyBodies.bodies {
            guard let star = SkyBodies.star(for: body, julianDay: julianDay) else { continue }
            let entity = Entity()
            entity.name = "body.\(body.rawValue)"
            let material = UnlitMaterial(color: uiColor(
                StarField.color(forColorIndex: star.colorIndex),
                brightness: 1
            ))
            if let mesh = try? StarFieldBuilder.mesh(bodyMesh(for: body, julianDay: julianDay), name: entity.name) {
                entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
            }
            entity.position = StarField.position(for: star, radius: Self.bodySphereRadius)
            group.addChild(entity)
            bodyNodes.append(BodyNode(body: body, entity: entity, star: star))
        }
    }

    func updateBodies(julianDay: Double) {
        guard abs(julianDay - bodyJulianDay) > 1.0 / 1440 else { return }
        bodyJulianDay = julianDay
        for index in bodyNodes.indices {
            let node = bodyNodes[index]
            guard let star = SkyBodies.star(for: node.body, julianDay: julianDay) else { continue }
            bodyNodes[index].star = star
            node.entity.position = StarField.position(for: star, radius: Self.bodySphereRadius)
            if node.body == .moon,
               let mesh = try? StarFieldBuilder.mesh(
                   bodyMesh(for: .moon, julianDay: julianDay),
                   name: node.entity.name
               ) {
                var model = node.entity.components[ModelComponent.self]
                model?.mesh = mesh
                if let model { node.entity.components.set(model) }
            }
        }
    }

    private func bodyMesh(for body: EphemerisBody, julianDay: Double) -> StarMeshData {
        if body == .moon {
            return MoonPhaseGlyph.mesh(
                phase: Ephemeris.moonPhase(julianDay: julianDay),
                radius: SkyBodies.moonDisplayRadius
            )
        }
        return StarFieldBuilder.sphere(
            center: .zero,
            radius: SkyBodies.displayRadius(for: body),
            segments: 10,
            rings: 6
        )
    }

    func nearestBody(to direction: SIMD3<Float>) -> Star? {
        let unit = simd_length(direction) > 0.0001 ? simd_normalize(direction) : direction
        var best: (star: Star, alignment: Float)?
        for node in bodyNodes {
            let alignment = simd_dot(unit, SkyPicker.direction(for: node.star))
            if best == nil || alignment > best!.alignment {
                best = (node.star, alignment)
            }
        }
        return best?.star
    }

    func pickBody(at point: CGPoint) -> Star? {
        guard let content else { return nil }
        var best: (star: Star, distance: CGFloat)?
        for node in bodyNodes {
            let world = field.convert(position: node.entity.position, to: nil)
            guard let projected = content.project(point: world, to: Self.space) else { continue }
            let distance = hypot(projected.x - point.x, projected.y - point.y)
            guard distance <= SkyPicker.crosshairRadius else { continue }
            if best == nil || distance < best!.distance {
                best = (node.star, distance)
            }
        }
        return best?.star
    }
}