import Foundation
import RealityKit
import SwiftUI
import UIKit

@MainActor
final class TiangongScene {
    static let space = NamedCoordinateSpace.named("tiangong")
    static let pickThreshold: CGFloat = 44

    private(set) var root = Entity()
    private var moduleNodes: [TiangongModuleID: Entity] = [:]
    private var cameraEntity: Entity?
    private var content: RealityViewCameraContent?
    private var isBuilt = false

    func build() {
        guard !isBuilt else { return }
        isBuilt = true
        root.name = "tiangong"

        let camera = Entity()
        camera.name = "camera"
        camera.components.set(
            PerspectiveCameraComponent(near: 0.02, far: 60, fieldOfViewInDegrees: 50)
        )
        root.addChild(camera)
        cameraEntity = camera

        addLab()
        addResource()
        addWing(.leftWing)
        addWing(.rightWing)
        addShenzhou()
        addLights()
    }

    func attach(_ content: RealityViewCameraContent) {
        self.content = content
    }

    func apply(rig: TiangongRig) {
        guard let cameraEntity else { return }
        let position = rig.cameraPosition() + TiangongLayout.center
        cameraEntity.position = position
        cameraEntity.look(at: TiangongLayout.center, from: position, relativeTo: nil)
    }

    /// 分离/装回。复位用绝对初值，不做相对增量——连续 10 轮拆装不能累积漂移。
    func applySeparation(_ separated: Set<TiangongModuleID>, animated: Bool) {
        for id in TiangongModuleID.allCases {
            guard let node = moduleNodes[id] else { continue }
            let target = separated.contains(id)
                ? TiangongDisassembly.separatedPosition(id)
                : TiangongLayout.restPosition(id)
            guard animated else {
                node.position = target
                continue
            }
            var transform = node.transform
            transform.translation = target
            node.move(to: transform, relativeTo: node.parent, duration: 0.4, timingFunction: .easeInOut)
        }
    }

    /// 拖动时把屏幕位移映射到世界位移，需要相机的右/上基向量。
    func cameraBasis() -> (right: SIMD3<Float>, up: SIMD3<Float>) {
        guard let cameraEntity else { return (SIMD3(1, 0, 0), SIMD3(0, 1, 0)) }
        let forward = simd_normalize(TiangongLayout.center - cameraEntity.position)
        var right = simd_cross(forward, SIMD3<Float>(0, 1, 0))
        if simd_length(right) < 1e-4 { right = SIMD3(1, 0, 0) }
        right = simd_normalize(right)
        return (right, simd_cross(right, forward))
    }

    func position(of id: TiangongModuleID) -> SIMD3<Float>? {
        moduleNodes[id]?.position
    }

    func setPosition(_ position: SIMD3<Float>, for id: TiangongModuleID) {
        moduleNodes[id]?.position = position
    }

    /// 排斥：沿判定给的方向弹开一点，让「装不进去」有可见的方向感。
    func push(_ id: TiangongModuleID, direction: SIMD3<Float>, distance: Float = 0.05) {
        guard let node = moduleNodes[id] else { return }
        var transform = node.transform
        transform.translation = node.position + simd_normalize(direction) * distance
        node.move(to: transform, relativeTo: node.parent, duration: 0.18, timingFunction: .easeOut)
    }

    func screenPoint(for id: TiangongModuleID) -> CGPoint? {
        guard let content, let node = moduleNodes[id] else { return nil }
        return content.project(point: node.position(relativeTo: nil), to: Self.space)
    }

    /// 用真实碰撞体拾取，不用「投影点距离」——舱段挨得很近时，
    /// 各个中心点的屏幕距离差不到几像素，会把所有触摸都判给同一个舱。
    func pick(at point: CGPoint) -> TiangongModuleID? {
        guard let content else { return nil }
        for hit in content.hitTest(point: point, in: Self.space, query: .all, mask: .all) {
            var entity: Entity? = hit.entity
            while let current = entity {
                if let id = TiangongModuleID(rawValue: current.name) { return id }
                entity = current.parent
            }
        }
        return nil
    }

    /// 往返自检：每个部件投影到屏幕后，点回原处应当命中它自己。
    /// 被前面的舱体挡住不算失败——射线打到近处的实体本来就是对的，记成 occluded。
    func verifyPicking() -> String {
        guard content != nil else { return "tiangong.pick ok=0/0 failed=no-content" }
        var passed = 0
        var failures: [String] = []
        var occluded: [String] = []
        for id in TiangongModuleID.allCases {
            guard let point = screenPoint(for: id) else {
                failures.append("\(id.rawValue):unprojectable")
                continue
            }
            let hit = pick(at: point)
            if hit == id {
                passed += 1
            } else if let hit {
                occluded.append("\(id.rawValue)->\(hit.rawValue)")
            } else {
                failures.append("\(id.rawValue):miss")
            }
        }
        let total = TiangongModuleID.allCases.count
        return "tiangong.pick ok=\(passed)/\(total)"
            + " occluded=\(occluded.isEmpty ? "none" : occluded.joined(separator: ","))"
            + " failed=\(failures.isEmpty ? "none" : failures.joined(separator: ","))"
    }

    var triangleEstimate: Int {
        var count = 0
        for entity in moduleNodes.values {
            for model in entity.components[ModelComponent.self]?.mesh.contents.models ?? [] {
                for part in model.parts {
                    count += (part.triangleIndices?.count ?? 0) / 3
                }
            }
        }
        return count
    }

    private func register(_ id: TiangongModuleID, _ entity: Entity) {
        entity.name = id.rawValue
        entity.position = TiangongLayout.restPosition(id)
        entity.generateCollisionShapes(recursive: true)
        entity.components.set(InputTargetComponent())
        root.addChild(entity)
        moduleNodes[id] = entity
    }

    private func addLab() {
        let seal = ModelEntity(
            mesh: MeshResource.generateCylinder(
                height: TiangongLayout.labSealDisplay,
                radius: TiangongScale.display(TiangongModel.maxDiameter) / 2
            ),
            materials: [SimpleMaterial(color: UIColor(white: 0.82, alpha: 1), roughness: 0.55, isMetallic: true)]
        )
        seal.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))

        let lab = Entity()
        lab.addChild(seal)

        // 前端的非密封后锥段：参考图上舱体在这里收细，再接到对接环。
        let cone = ModelEntity(
            mesh: MeshResource.generateCone(
                height: TiangongLayout.labConeDisplay,
                radius: TiangongScale.display(TiangongModel.maxDiameter) / 2
            ),
            materials: [SimpleMaterial(color: UIColor(white: 0.7, alpha: 1), roughness: 0.6, isMetallic: true)]
        )
        // 锥尖朝 +Z（朝向神舟那一侧）；用 +π/2 会反过来，参考图上两艘飞行器的锥尖是相对的。
        cone.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
        cone.position = SIMD3(0, 0, TiangongLayout.labSealDisplay / 2 + TiangongLayout.labConeDisplay / 2)
        lab.addChild(cone)

        let port = ModelEntity(
            mesh: MeshResource.generateCylinder(
                height: 0.012,
                radius: TiangongScale.display(TiangongModel.maxDiameter) / 2 * 0.42
            ),
            materials: [SimpleMaterial(color: UIColor(white: 0.35, alpha: 1), roughness: 0.4, isMetallic: true)]
        )
        port.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        port.position = SIMD3(
            0, 0,
            TiangongLayout.labSealDisplay + TiangongLayout.labConeDisplay - TiangongLayout.labCenter.z
        )
        lab.addChild(port)

        register(.lab, lab)
    }

    private func addResource() {
        let mesh = MeshResource.generateCylinder(
            height: TiangongLayout.resourceLengthDisplay,
            radius: TiangongScale.display(TiangongModel.resourceDiameter) / 2
        )
        let entity = ModelEntity(
            mesh: mesh,
            materials: [SimpleMaterial(color: UIColor(red: 0.72, green: 0.55, blue: 0.22, alpha: 1), roughness: 0.35, isMetallic: true)]
        )
        entity.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        register(.resource, entity)
    }

    private func addWing(_ id: TiangongModuleID) {
        let mesh = MeshResource.generateBox(
            width: TiangongScale.display(TiangongModel.wingLength),
            height: 0.004,
            depth: TiangongScale.display(TiangongModel.wingWidth)
        )
        let entity = ModelEntity(
            mesh: mesh,
            materials: [SimpleMaterial(color: UIColor(red: 0.10, green: 0.15, blue: 0.32, alpha: 1), roughness: 0.35, isMetallic: false)]
        )
        let spine = ModelEntity(
            mesh: MeshResource.generateBox(
                width: TiangongScale.display(TiangongModel.wingLength),
                height: 0.006,
                depth: 0.006
            ),
            materials: [SimpleMaterial(color: UIColor(white: 0.85, alpha: 1), roughness: 0.3, isMetallic: true)]
        )
        entity.addChild(spine)
        register(id, entity)
    }

    /// 神舟三舱，按参考图从前往后：轨道舱（对接端）→ 返回舱（钟形，锥尖朝天宫）→ 推进舱（带两片翼）。
    private func addShenzhou() {
        let holder = Entity()
        let length = TiangongScale.display(TiangongModel.shenzhouLength)
        let radius = TiangongScale.display(TiangongModel.shenzhouDiameter) / 2

        let orbitalLength = TiangongScale.display(TiangongModel.shenzhouOrbitalLength)
        let capsuleLength = TiangongScale.display(TiangongModel.shenzhouCapsuleLength)
        let serviceLength = TiangongScale.display(TiangongModel.shenzhouServiceLength)

        let orbital = ModelEntity(
            mesh: MeshResource.generateCylinder(height: orbitalLength, radius: radius * 0.74),
            materials: [SimpleMaterial(color: UIColor(white: 0.88, alpha: 1), roughness: 0.45, isMetallic: false)]
        )
        orbital.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        orbital.position = SIMD3(0, 0, -length / 2 + orbitalLength / 2)
        holder.addChild(orbital)

        let capsule = ModelEntity(
            mesh: MeshResource.generateCone(height: capsuleLength, radius: radius),
            materials: [SimpleMaterial(color: UIColor(white: 0.75, alpha: 1), roughness: 0.5, isMetallic: false)]
        )
        capsule.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
        capsule.position = SIMD3(0, 0, -length / 2 + orbitalLength + capsuleLength / 2)
        holder.addChild(capsule)

        let service = ModelEntity(
            mesh: MeshResource.generateCylinder(height: serviceLength, radius: radius),
            materials: [SimpleMaterial(color: UIColor(white: 0.6, alpha: 1), roughness: 0.6, isMetallic: true)]
        )
        service.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        service.position = SIMD3(0, 0, length / 2 - serviceLength / 2)
        holder.addChild(service)

        for sign in [Float(-1), 1] {
            let wing = ModelEntity(
                mesh: MeshResource.generateBox(
                    width: 0.004,
                    height: TiangongScale.display(TiangongModel.shenzhouWingLength),
                    depth: TiangongScale.display(TiangongModel.shenzhouWingWidth)
                ),
                materials: [SimpleMaterial(color: UIColor(red: 0.10, green: 0.15, blue: 0.32, alpha: 1), roughness: 0.35, isMetallic: false)]
            )
            wing.position = SIMD3(
                0,
                sign * (radius + TiangongScale.display(TiangongModel.shenzhouWingLength) / 2),
                service.position.z
            )
            holder.addChild(wing)
        }

        register(.shenzhou, holder)
    }

    private func addLights() {
        let key = Entity()
        key.components.set(
            DirectionalLightComponent(
                color: .white,
                intensity: 2600,
                isRealWorldProxy: false
            )
        )
        key.orientation = simd_quatf(angle: -.pi / 4, axis: SIMD3(1, 0, 0))
        root.addChild(key)

        let fill = Entity()
        fill.components.set(
            DirectionalLightComponent(
                color: UIColor(red: 0.65, green: 0.75, blue: 1, alpha: 1),
                intensity: 900,
                isRealWorldProxy: false
            )
        )
        fill.orientation = simd_quatf(angle: .pi / 3, axis: SIMD3(0, 1, 0))
        root.addChild(fill)
    }
}

struct TiangongRig: Equatable, Sendable {
    static let pitchRange: ClosedRange<Float> = -0.9...1.1
    static let distanceRange: ClosedRange<Float> = 0.55...4.5
    static let yawSensitivity: Float = 0.006
    static let pitchSensitivity: Float = 0.005

    var yaw: Float = 0.42
    var pitch: Float = 0.28
    var distance: Float

    init(yaw: Float = 1.15, pitch: Float = 0.32, distance: Float = 3.3) {
        self.yaw = yaw
        self.pitch = pitch
        self.distance = distance
    }

    func cameraPosition() -> SIMD3<Float> {
        let horizontal = distance * cos(pitch)
        return SIMD3(horizontal * sin(yaw), distance * sin(pitch), horizontal * cos(yaw))
    }

    mutating func rotate(deltaX: Float, deltaY: Float) {
        yaw += deltaX * Self.yawSensitivity
        pitch = min(max(pitch + deltaY * Self.pitchSensitivity, Self.pitchRange.lowerBound), Self.pitchRange.upperBound)
    }

    mutating func dolly(scale: Float) {
        distance = min(max(distance / scale, Self.distanceRange.lowerBound), Self.distanceRange.upperBound)
    }
}
