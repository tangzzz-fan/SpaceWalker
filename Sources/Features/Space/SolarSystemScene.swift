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
    private var moonNodes: [String: Entity] = [:]
    private var beltNodes: [Entity] = []
    private var cameraEntity: Entity?
    private var content: RealityViewCameraContent?
    private var isBuilt = false
    let firstFrame = FirstFrameFlag()
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

        for moon in SolarSatellites.moons {
            let node = makeMoonNode(moon)
            node.isEnabled = false
            moonNodes[moon.id] = node
            bodyNodes[moon.parent]?.addChild(node)
        }

        let asteroid = makeBeltNode(
            SolarBelts.asteroidParticles,
            name: "belt.asteroid",
            color: UIColor(white: 0.55, alpha: 1)
        )
        let kuiper = makeBeltNode(
            SolarBelts.kuiperParticles,
            name: "belt.kuiper",
            color: UIColor(white: 0.42, alpha: 1)
        )
        beltNodes = [asteroid, kuiper]
        root.addChild(asteroid)
        root.addChild(kuiper)
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

    func apply(
        julianDay: Double,
        showsOrbits: Bool,
        rig: OrbitRig,
        selected: BodyID?,
        trueScale: Bool = false
    ) {
        for planet in SolarSystem.bodies {
            guard let node = bodyNodes[planet.id] else { continue }
            node.position = SolarLayout.position(for: planet, julianDay: julianDay)
            let base: Float = trueScale ? SolarLayout.trueScaleFactor(for: planet) : 1
            let scale: Float = planet.id == selected ? base * Self.selectedScale : base
            node.scale = SIMD3(scale, scale, scale)
        }
        for node in orbitNodes.values {
            node.isEnabled = showsOrbits
        }
        for moon in SolarSatellites.moons {
            guard let node = moonNodes[moon.id] else { continue }
            node.isEnabled = !trueScale && moon.parent == selected
            node.position = SolarSatellites.position(for: moon, julianDay: julianDay)
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
        // 093 预算：generateSphere 单球约 9.5k 三角，15 个球就爆 20k。
        // 行星用 16x12 低模球（384 三角），全场景含卫星与带 ≤13k。
        let sphere = StarFieldBuilder.sphere(center: .zero, radius: radius, segments: 16, rings: 12)
        let mesh = (try? StarFieldBuilder.mesh(sphere, name: planet.id.rawValue))
            ?? MeshResource.generateSphere(radius: radius)

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
                majorSegments: 64,
                minorSegments: 6
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

    private func makeMoonNode(_ moon: SolarMoon) -> Entity {
        let entity = Entity()
        entity.name = "moon.\(moon.id)"
        let sphere = StarFieldBuilder.sphere(
            center: .zero, radius: SolarSatellites.displayRadius(for: moon), segments: 8, rings: 6
        )
        let mesh = (try? StarFieldBuilder.mesh(sphere, name: entity.name))
            ?? MeshResource.generateSphere(radius: SolarSatellites.displayRadius(for: moon))
        var material = PhysicallyBasedMaterial()
        let base = UIColor(hex: moon.colorHex)
        material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: base)
        material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.8)
        material.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: 0)
        material.emissiveColor = PhysicallyBasedMaterial.EmissiveColor(color: base.dimmed(0.5))
        material.emissiveIntensity = 1.0
        entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        return entity
    }

    /// 一条带 = 一个实体 + 一份合并网格（每颗粒子一个低模球），
    /// 只占 1 draw call；粒子位置确定性生成，预算可复算。
    private func makeBeltNode(
        _ particles: [SolarBelts.Particle],
        name: String,
        color: UIColor
    ) -> Entity {
        let entity = Entity()
        entity.name = name
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        // 每颗粒子一个四面体（4 顶点 / 4 三角）：远看是点，预算只有球体的 1/12。
        let tetra: [SIMD3<Float>] = [
            simd_normalize(SIMD3(1, 1, 1)),
            simd_normalize(SIMD3(1, -1, -1)),
            simd_normalize(SIMD3(-1, 1, -1)),
            simd_normalize(SIMD3(-1, -1, 1)),
        ]
        let faces: [(UInt32, UInt32, UInt32)] = [(0, 1, 2), (0, 3, 1), (0, 2, 3), (1, 3, 2)]
        for particle in particles {
            let base = UInt32(positions.count)
            for normal in tetra {
                positions.append(particle.position + normal * particle.radius)
                normals.append(normal)
            }
            for face in faces {
                indices.append(contentsOf: [base + face.0, base + face.1, base + face.2])
            }
        }
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        if let mesh = try? MeshResource.generate(from: [descriptor]) {
            let material = UnlitMaterial(color: color)
            entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        }
        return entity
    }

    var triangleEstimate: Int {
        triangles(in: root)
    }

    var entityCount: Int {
        entities(in: root)
    }

    /// 只数启用中的模型——禁用实体不进渲染，不算 draw call。
    var modelEntityCount: Int {
        models(in: root)
    }

    private func entities(in entity: Entity) -> Int {
        1 + entity.children.reduce(0) { $0 + entities(in: $1) }
    }

    private func models(in entity: Entity) -> Int {
        guard entity.isEnabled else { return 0 }
        let selfCount = entity.components[ModelComponent.self] == nil ? 0 : 1
        return selfCount + entity.children.reduce(0) { $0 + models(in: $1) }
    }

    private func triangles(in entity: Entity) -> Int {
        var count = 0
        if let mesh = entity.components[ModelComponent.self]?.mesh {
            for model in mesh.contents.models {
                for part in model.parts {
                    count += (part.triangleIndices?.count ?? 0) / 3
                }
            }
        }
        for child in entity.children {
            count += triangles(in: child)
        }
        return count
    }

    private func makeOrbitNode(_ planet: SolarBody) -> Entity {
        let entity = Entity()
        entity.name = "orbit.\(planet.id.rawValue)"

        let ring = OrbitRing.torus(
            majorRadius: SolarLayout.orbitRadius(for: planet),
            minorRadius: SolarLayout.orbitLineRadius,
            majorSegments: 96,
            minorSegments: 4
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


final class FirstFrameFlag: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)

    func claim() -> Bool {
        lock.withLock { claimed in
            guard !claimed else { return false }
            claimed = true
            return true
        }
    }

    var hasClaimed: Bool {
        lock.withLock { $0 }
    }
}
