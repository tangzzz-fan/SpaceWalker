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

    /// RealityView 每次重建都会拿到一个新的 `RealityViewCameraContent`。
    /// 复用同一个 root 二次 add 进新 scene 不生效（页面重建后一片黑），
    /// 所以每次进路由都重建整棵树——五个实体、几十个三角形，成本可忽略。
    func rebuild() {
        root.removeFromParent()
        root = Entity()
        moduleNodes.removeAll()
        cameraEntity = nil
        isBuilt = false
        build()
    }

    func build() {
        guard !isBuilt else { return }
        isBuilt = true
        root.name = "tiangong"
        let started = CACurrentMediaTime()

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

        let elapsed = Int((CACurrentMediaTime() - started) * 1000)
        SessionLog.append(
            "tiangong.build ms=\(elapsed) triangles=\(triangleEstimate)"
                + " entities=\(entityCount) models=\(modelEntityCount)"
        )
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

    /// 飞船姿态：绕竖直轴偏航、绕横轴俯仰。角度是度，视觉与判定共用同一个值。
    func setAttitude(yawDegrees: Float, pitchDegrees: Float, for id: TiangongModuleID) {
        guard let node = moduleNodes[id] else { return }
        let yaw = simd_quatf(angle: yawDegrees * .pi / 180, axis: SIMD3(0, 1, 0))
        let pitch = simd_quatf(angle: pitchDegrees * .pi / 180, axis: SIMD3(1, 0, 0))
        node.orientation = yaw * pitch
    }

    /// 排斥：沿判定给的方向弹开一点，让「装不进去」有可见的方向感。
    func push(_ id: TiangongModuleID, direction: SIMD3<Float>, distance: Float = 0.05) {
        guard let node = moduleNodes[id] else { return }
        var transform = node.transform
        transform.translation = node.position + simd_normalize(direction) * distance
        node.move(to: transform, relativeTo: node.parent, duration: 0.18, timingFunction: .easeOut)
    }

    /// 合拢：所有模块同时微微鼓起再回落。
    /// 不给 root 做缩放——相机会跟着缩，视觉上变成「拉近」，而不是「组件合在一起」。
    func playClosureAnimation() {
        let bulge = SIMD3<Float>(repeating: 1.03)
        for node in moduleNodes.values {
            var transform = node.transform
            transform.scale = bulge
            node.move(to: transform, relativeTo: node.parent, duration: 0.16, timingFunction: .easeOut)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            for node in moduleNodes.values {
                var transform = node.transform
                transform.scale = .one
                node.move(to: transform, relativeTo: node.parent, duration: 0.24, timingFunction: .easeInOut)
            }
        }
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
        moduleNodes.values.reduce(0) { $0 + triangles(in: $1) }
    }

    var entityCount: Int {
        moduleNodes.values.reduce(0) { $0 + entities(in: $1) }
    }

    var modelEntityCount: Int {
        moduleNodes.values.reduce(0) { $0 + models(in: $1) }
    }

    private func entities(in entity: Entity) -> Int {
        1 + entity.children.reduce(0) { $0 + entities(in: $1) }
    }

    private func models(in entity: Entity) -> Int {
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

    private func register(_ id: TiangongModuleID, _ entity: Entity) {
        entity.name = id.rawValue
        entity.position = TiangongLayout.restPosition(id)
        entity.generateCollisionShapes(recursive: true)
        entity.components.set(InputTargetComponent())
        root.addChild(entity)
        moduleNodes[id] = entity
    }

    private func addLab() {
        let axis = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        let radius = TiangongScale.display(TiangongModel.maxDiameter) / 2
        let resourceRadius = TiangongScale.display(TiangongModel.resourceDiameter) / 2
        let tipRadius = radius * TiangongModel.labConeTipRatio
        let sealHeight = TiangongScale.display(TiangongModel.labSealLength)
        let coneHeight = TiangongScale.display(TiangongModel.labConeLength)
        let rearHeight = TiangongScale.display(TiangongModel.labRearConeLength)

        let lab = Entity()

        let seal = ModelEntity(
            mesh: MeshResource.generateCylinder(height: sealHeight, radius: radius),
            materials: [TiangongMaterials.labBody()]
        )
        seal.name = "lab-seal"
        seal.orientation = axis
        seal.position = SIMD3(0, 0, TiangongLayout.labCylinderOffset)
        lab.addChild(seal)

        let rear = ModelEntity(
            mesh: TiangongMesh.frustum(topRadius: radius, bottomRadius: resourceRadius, height: rearHeight, caps: .none),
            materials: [TiangongMaterials.labCone()]
        )
        rear.name = "lab-rear-cone"
        rear.orientation = axis
        rear.position = SIMD3(0, 0, TiangongLayout.labRearConeOffset)
        lab.addChild(rear)

        let cone = ModelEntity(
            mesh: TiangongMesh.frustum(topRadius: tipRadius, bottomRadius: radius, height: coneHeight, caps: .none),
            materials: [TiangongMaterials.labCone()]
        )
        cone.name = "lab-cone"
        cone.orientation = axis
        cone.position = SIMD3(0, 0, TiangongLayout.labConeOffset)
        lab.addChild(cone)

        let port = ModelEntity(
            mesh: MeshResource.generateCylinder(height: 0.014, radius: tipRadius),
            materials: [TiangongMaterials.hardware(0.35)]
        )
        port.name = "port"
        port.orientation = axis
        port.position = SIMD3(0, 0, TiangongLayout.labLengthDisplay / 2)

        let tunnel = ModelEntity(
            mesh: MeshResource.generateCylinder(height: 0.006, radius: tipRadius * 0.56),
            materials: [TiangongMaterials.inner()]
        )
        tunnel.name = "port-tunnel"
        tunnel.orientation = axis
        tunnel.position = SIMD3(0, 0, 0.006)
        port.addChild(tunnel)

        for index in 0..<TiangongModel.dockingLatchCount {
            let angle = Float(index) / Float(TiangongModel.dockingLatchCount) * 2 * .pi
            let latch = ModelEntity(
                mesh: MeshResource.generateBox(
                    width: tipRadius * 0.30,
                    height: 0.016,
                    depth: tipRadius * 0.22
                ),
                materials: [TiangongMaterials.hardware(0.55)]
            )
            latch.name = "port-latch-\(index)"
            latch.position = SIMD3(
                cos(angle) * tipRadius * 0.82,
                0,
                sin(angle) * tipRadius * 0.82
            )
            latch.orientation = simd_quatf(angle: -angle, axis: SIMD3(0, 1, 0))
            port.addChild(latch)
        }

        lab.addChild(port)

        for (index, x) in [Float(-0.032), 0.032].enumerated() {
            let frame = ModelEntity(
                mesh: MeshResource.generateCylinder(height: 0.004, radius: 0.0115),
                materials: [TiangongMaterials.hardware(0.82)]
            )
            frame.name = "lab-window-\(index)"
            let y = max(radius * radius - x * x, 0).squareRoot()
            frame.position = SIMD3(x, y, TiangongLayout.labCylinderOffset + 0.032)

            let glass = ModelEntity(
                mesh: MeshResource.generateCylinder(height: 0.005, radius: 0.008),
                materials: [TiangongMaterials.inner()]
            )
            glass.name = "lab-window-glass-\(index)"
            glass.position = SIMD3(0, 0.0008, 0)
            frame.addChild(glass)
            lab.addChild(frame)
        }

        register(.lab, lab)
    }

    private func addResource() {
        let holder = Entity()
        let radius = TiangongScale.display(TiangongModel.resourceDiameter) / 2
        let length = TiangongLayout.resourceLengthDisplay

        let body = ModelEntity(
            mesh: MeshResource.generateCylinder(height: length, radius: radius),
            materials: [TiangongMaterials.resource()]
        )
        body.name = "resource-body"
        body.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        holder.addChild(body)

        let aft = -length / 2
        let aftRotation = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))

        let mainPlacements = (0..<TiangongModel.mainEngineCount).map { index in
            let side: Float = index == 0 ? -1 : 1
            return TiangongMesh.placement(SIMD3(side * radius * 0.42, 0, aft - 0.006), aftRotation)
        }
        let engines = ModelEntity(
            mesh: TiangongMesh.revolve(
                profile: TiangongModel.nozzleProfile.map { SIMD2($0.x * 0.018, $0.y) },
                height: 0.022,
                sides: 20,
                instances: mainPlacements
            ),
            materials: [TiangongMaterials.hardware(0.32)]
        )
        engines.name = "resource-engines"
        holder.addChild(engines)

        let vernierPlacements = (0..<TiangongModel.vernierCount).map { index in
            let angle = Float(index) / Float(TiangongModel.vernierCount) * 2 * .pi
            return TiangongMesh.placement(
                SIMD3(cos(angle) * radius * 0.7, sin(angle) * radius * 0.7, aft - 0.002),
                aftRotation
            )
        }
        let verniers = ModelEntity(
            mesh: TiangongMesh.revolve(
                profile: TiangongModel.nozzleProfile.map { SIMD2($0.x * 0.009, $0.y) },
                height: 0.012,
                sides: 16,
                instances: vernierPlacements
            ),
            materials: [TiangongMaterials.hardware(0.45)]
        )
        verniers.name = "resource-verniers"
        holder.addChild(verniers)

        let mast = ModelEntity(
            mesh: MeshResource.generateCylinder(height: 0.02, radius: 0.0035),
            materials: [TiangongMaterials.hardware(0.7)]
        )
        mast.name = "antenna-mast"
        mast.position = SIMD3(0, radius + 0.006, 0)
        holder.addChild(mast)

        let dishRadius = TiangongScale.display(TiangongModel.relayAntennaDiameter) / 2
        let dish = ModelEntity(
            mesh: TiangongMesh.revolve(
                profile: TiangongModel.dishProfile.map { SIMD2($0.x * dishRadius, $0.y) },
                height: 0.008,
                sides: 24,
                caps: .none
            ),
            materials: [TiangongMaterials.hardware(0.78)]
        )
        dish.name = "antenna-dish"
        dish.position = SIMD3(0, radius + 0.020, 0)
        holder.addChild(dish)

        register(.resource, holder)
    }

    private func addWing(_ id: TiangongModuleID) {
        let side: Float = id == .leftWing ? -1 : 1
        let total = TiangongScale.display(TiangongModel.wingLength)
        let gap = TiangongScale.display(TiangongModel.wingPanelGap)
        let count = Float(TiangongModel.wingPanelCount)
        let panel = (total - gap * (count - 1)) / count
        let width = TiangongScale.display(TiangongModel.wingWidth)

        let holder = Entity()

        let backing = ModelEntity(
            mesh: MeshResource.generateBox(width: total, height: 0.0016, depth: width * 0.97),
            materials: [TiangongMaterials.inner()]
        )
        backing.name = "backing"
        backing.position = SIMD3(0, -0.0024, 0)
        holder.addChild(backing)

        let panelMaterial = TiangongMaterials.wing()
        for index in 0..<TiangongModel.wingPanelCount {
            let node = ModelEntity(
                mesh: MeshResource.generateBox(width: panel, height: 0.003, depth: width),
                materials: [panelMaterial]
            )
            node.name = "panel-\(index)"
            node.position = SIMD3(
                side * (panel / 2 + Float(index) * (panel + gap) - total / 2),
                0,
                0
            )
            holder.addChild(node)
        }

        let spine = ModelEntity(
            mesh: MeshResource.generateBox(width: total, height: 0.006, depth: 0.006),
            materials: [TiangongMaterials.hardware(0.85)]
        )
        spine.name = "spine"
        spine.position = SIMD3(0, 0, width / 2 - 0.004)
        holder.addChild(spine)

        let hinge = ModelEntity(
            mesh: MeshResource.generateBox(width: 0.018, height: 0.012, depth: width * 0.9),
            materials: [TiangongMaterials.hardware(0.72)]
        )
        hinge.name = "hinge"
        hinge.position = SIMD3(-side * total / 2 + side * 0.009, 0, 0)
        holder.addChild(hinge)

        register(id, holder)
    }

    /// 神舟三舱，按参考图从前往后：轨道舱（对接端）→ 返回舱（钟形）→ 推进舱（带两片翼）。
    private func addShenzhou() {
        let holder = Entity()
        let length = TiangongScale.display(TiangongModel.shenzhouLength)
        let radius = TiangongScale.display(TiangongModel.shenzhouDiameter) / 2

        let orbitalLength = TiangongScale.display(TiangongModel.shenzhouOrbitalLength)
        let capsuleLength = TiangongScale.display(TiangongModel.shenzhouCapsuleLength)
        let serviceLength = TiangongScale.display(TiangongModel.shenzhouServiceLength)

        let orbital = ModelEntity(
            mesh: MeshResource.generateCylinder(
                height: orbitalLength,
                radius: radius * TiangongModel.shenzhouOrbitalRatio
            ),
            materials: [TiangongMaterials.spacecraft()]
        )
        orbital.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        orbital.position = SIMD3(0, 0, -length / 2 + orbitalLength / 2)
        holder.addChild(orbital)

        let capsule = ModelEntity(
            mesh: TiangongMesh.revolve(
                profile: TiangongModel.capsuleProfile.map { SIMD2($0.x * radius, $0.y) },
                height: capsuleLength,
                caps: .none
            ),
            materials: [TiangongMaterials.capsule()]
        )
        capsule.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
        capsule.position = SIMD3(0, 0, -length / 2 + orbitalLength + capsuleLength / 2)
        holder.addChild(capsule)

        let service = ModelEntity(
            mesh: MeshResource.generateCylinder(height: serviceLength, radius: radius),
            materials: [TiangongMaterials.hardware(0.6)]
        )
        service.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        service.position = SIMD3(0, 0, length / 2 - serviceLength / 2)
        holder.addChild(service)

        let aftRotation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        let enginePlacements = (0..<TiangongModel.vernierCount).map { index in
            let angle = Float(index) / Float(TiangongModel.vernierCount) * 2 * .pi
            return TiangongMesh.placement(
                SIMD3(cos(angle) * radius * 0.55, sin(angle) * radius * 0.55, length / 2 + 0.006),
                aftRotation
            )
        }
        let engines = ModelEntity(
            mesh: TiangongMesh.revolve(
                profile: TiangongModel.nozzleProfile.map { SIMD2($0.x * 0.011, $0.y) },
                height: 0.014,
                sides: 16,
                instances: enginePlacements
            ),
            materials: [TiangongMaterials.hardware(0.42)]
        )
        engines.name = "shenzhou-engines"
        holder.addChild(engines)

        for sign in [Float(-1), 1] {
            let wing = ModelEntity(
                mesh: MeshResource.generateBox(
                    width: 0.004,
                    height: TiangongScale.display(TiangongModel.shenzhouWingLength),
                    depth: TiangongScale.display(TiangongModel.shenzhouWingWidth)
                ),
                materials: [TiangongMaterials.wing()]
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

        let rim = Entity()
        rim.components.set(
            DirectionalLightComponent(
                color: UIColor(red: 0.58, green: 0.72, blue: 1, alpha: 1),
                intensity: 1400,
                isRealWorldProxy: false
            )
        )
        rim.position = SIMD3(-1.8, 1.2, -1.6)
        rim.look(at: TiangongLayout.center, from: rim.position, relativeTo: nil)
        root.addChild(rim)
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
