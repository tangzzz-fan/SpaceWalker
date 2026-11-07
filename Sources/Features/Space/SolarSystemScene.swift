import Foundation
import os
import RealityKit
import SwiftUI
import UIKit

@MainActor
final class SolarSystemScene {
    static let coordinateSpaceName = "space"
    static let space = NamedCoordinateSpace.named(coordinateSpaceName)
    static let pickThreshold: CGFloat = 44
    static let selectedScale: Float = 1.3

    private(set) var root = Entity()
    private var bodyNodes: [BodyID: Entity] = [:]
    private var orbitNodes: [BodyID: Entity] = [:]
    private var cameraEntity: Entity?
    private var content: RealityViewCameraContent?
    private var isBuilt = false
    private let firstFrame = FirstFrameFlag()
    private var firstFrameSubscription: EventSubscription?

    func build() {
        guard !isBuilt else { return }
        isBuilt = true
        root.name = "solarSystem"

        let camera = Entity()
        camera.name = "camera"
        camera.components.set(
            PerspectiveCameraComponent(near: 0.05, far: 500, fieldOfViewInDegrees: 55)
        )
        root.addChild(camera)
        cameraEntity = camera

        for planet in SolarSystem.bodies {
            let node = makeBodyNode(planet)
            bodyNodes[planet.id] = node
            root.addChild(node)

            if planet.semiMajorAxisAU > 0 {
                let orbit = makeOrbitNode(planet)
                orbitNodes[planet.id] = orbit
                root.addChild(orbit)
            }
        }
    }

    func attach(_ content: RealityViewCameraContent) {
        self.content = content
        guard firstFrameSubscription == nil else { return }
        let flag = firstFrame
        firstFrameSubscription = content.subscribe(to: SceneEvents.Update.self) { _ in
            guard flag.claim() else { return }
            SessionLog.append("space.firstFrame ms=\(AppClock.elapsedMilliseconds())")
        }
    }

    func apply(days: Double, showsOrbits: Bool, rig: OrbitRig, selected: BodyID?) {
        for planet in SolarSystem.bodies {
            guard let node = bodyNodes[planet.id] else { continue }
            node.position = SolarLayout.position(for: planet, days: days)
            let scale: Float = planet.id == selected ? Self.selectedScale : 1
            node.scale = SIMD3(scale, scale, scale)
        }
        for node in orbitNodes.values {
            node.isEnabled = showsOrbits
        }
        if let cameraEntity {
            let position = rig.cameraPosition()
            cameraEntity.position = position
            cameraEntity.look(at: .zero, from: position, relativeTo: nil)
        }
    }

    func pick(at point: CGPoint) -> BodyID? {
        guard let content else { return nil }
        var best: (id: BodyID, distance: CGFloat)?

        for planet in SolarSystem.bodies {
            guard let node = bodyNodes[planet.id] else { continue }
            let world = node.position(relativeTo: nil)
            guard let projected = content.project(point: world, to: Self.space) else { continue }
            let distance = hypot(projected.x - point.x, projected.y - point.y)
            guard distance <= Self.pickThreshold else { continue }
            if best == nil || distance < best!.distance {
                best = (planet.id, distance)
            }
        }
        return best?.id
    }

    func screenPoint(for id: BodyID) -> CGPoint? {
        guard let content, let node = bodyNodes[id] else { return nil }
        return content.project(point: node.position(relativeTo: nil), to: Self.space)
    }

    func verifyPicking() -> String {
        guard let content else { return "pick.roundtrip ok=0/0 failed=no-content" }
        var passed = 0
        var failures: [String] = []

        for planet in SolarSystem.bodies {
            guard let node = bodyNodes[planet.id],
                  let screen = content.project(point: node.position(relativeTo: nil), to: Self.space)
            else {
                failures.append("\(planet.id.rawValue):unprojectable")
                continue
            }
            let hit = pick(at: screen)
            if hit == planet.id {
                passed += 1
            } else {
                failures.append("\(planet.id.rawValue)->\(hit?.rawValue ?? "nil")")
            }
        }

        return "pick.roundtrip ok=\(passed)/\(SolarSystem.bodies.count)"
            + " failed=\(failures.isEmpty ? "none" : failures.joined(separator: ","))"
    }

    private func makeBodyNode(_ planet: SolarBody) -> Entity {
        let entity = Entity()
        entity.name = planet.id.rawValue

        let radius = SolarLayout.bodyRadius(for: planet)
        let base = UIColor(hex: planet.colorHex)
        let mesh = MeshResource.generateSphere(radius: radius)

        if planet.kind == .star {
            let material = UnlitMaterial(color: base)
            entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
            entity.components.set(
                PointLightComponent(
                    cgColor: UIColor(red: 1, green: 0.94, blue: 0.84, alpha: 1).cgColor,
                    intensity: 120_000,
                    attenuationRadius: 60
                )
            )
        } else {
            var material = PhysicallyBasedMaterial()
            material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: base)
            material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.72)
            material.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: 0)
            material.emissiveColor = PhysicallyBasedMaterial.EmissiveColor(color: base.dimmed(0.62))
            material.emissiveIntensity = 1.0
            entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        }

        if planet.hasRing {
            let ring = OrbitRing.torus(
                majorRadius: radius * 1.9,
                minorRadius: radius * 0.075,
                majorSegments: 96,
                minorSegments: 8
            )
            if let ringMesh = try? OrbitRing.mesh(ring, name: "saturnRing") {
                let ringEntity = Entity()
                ringEntity.name = "\(planet.id.rawValue).ring"
                let material = UnlitMaterial(color: UIColor(white: 0.74, alpha: 1))
                ringEntity.components.set(ModelComponent(mesh: ringMesh, materials: [material]))
                ringEntity.scale = SIMD3(1, 0.22, 1)
                entity.addChild(ringEntity)
            }
        }

        return entity
    }

    private func makeOrbitNode(_ planet: SolarBody) -> Entity {
        let entity = Entity()
        entity.name = "orbit.\(planet.id.rawValue)"

        let ring = OrbitRing.torus(
            majorRadius: SolarLayout.orbitRadius(for: planet),
            minorRadius: SolarLayout.orbitLineRadius,
            majorSegments: 160,
            minorSegments: 5
        )
        if let mesh = try? OrbitRing.mesh(ring, name: entity.name) {
            let material = UnlitMaterial(color: UIColor(white: 0.26, alpha: 1))
            entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        }
        return entity
    }
}

private extension UIColor {    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    func dimmed(_ factor: CGFloat) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return UIColor(red: red * factor, green: green * factor, blue: blue * factor, alpha: alpha)
    }
}


private final class FirstFrameFlag: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)

    func claim() -> Bool {
        lock.withLock { claimed in
            guard !claimed else { return false }
            claimed = true
            return true
        }
    }
}
