import Foundation
import RealityKit
import SwiftUI
import UIKit

@MainActor
final class EarthOrbitScene {
    static let coordinateSpaceName = "earthOrbit"
    static let space = NamedCoordinateSpace.named(coordinateSpaceName)

    private(set) var root = Entity()
    private var earthNode: Entity?
    private var moonNode: Entity?
    private var tiangongNode: Entity?
    private var orbitNode: Entity?
    private var trackNode: Entity?
    private var sunLight: Entity?
    private var cameraEntity: Entity?
    private var content: RealityViewCameraContent?
    private var isBuilt = false
    private var lastStop: EarthOrbitCameraStop?
    private var transitionEnd: TimeInterval?

    func build() {
        guard !isBuilt else { return }
        isBuilt = true
        root.name = "earthOrbit"

        let camera = Entity()
        camera.name = "camera"
        camera.components.set(
            PerspectiveCameraComponent(near: 0.05, far: 4000, fieldOfViewInDegrees: 55)
        )
        root.addChild(camera)
        cameraEntity = camera

        let earth = Entity()
        earth.name = "earth"
        var earthMaterial = PhysicallyBasedMaterial()
        earthMaterial.baseColor = PhysicallyBasedMaterial.BaseColor(
            tint: UIColor(red: 0.16, green: 0.38, blue: 0.72, alpha: 1)
        )
        earthMaterial.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.85)
        earthMaterial.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: 0)
        earth.components.set(ModelComponent(
            mesh: MeshResource.generateSphere(radius: EarthOrbitGeometry.earthDisplayRadius),
            materials: [earthMaterial]
        ))
        root.addChild(earth)
        earthNode = earth

        let moon = Entity()
        moon.name = "moon"
        var moonMaterial = PhysicallyBasedMaterial()
        moonMaterial.baseColor = PhysicallyBasedMaterial.BaseColor(
            tint: UIColor(white: 0.72, alpha: 1)
        )
        moonMaterial.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.95)
        moon.components.set(ModelComponent(
            mesh: MeshResource.generateSphere(radius: EarthOrbitGeometry.moonDisplayRadius),
            materials: [moonMaterial]
        ))
        root.addChild(moon)
        moonNode = moon

        let orbit = Entity()
        orbit.name = "tiangong.orbit"
        let ring = OrbitRing.torus(
            majorRadius: EarthOrbitGeometry.tiangongOrbitDisplayRadius,
            minorRadius: 0.004,
            majorSegments: 180,
            minorSegments: 5
        )
        if let mesh = try? OrbitRing.mesh(ring, name: "tiangong.orbit") {
            orbit.components.set(ModelComponent(
                mesh: mesh,
                materials: [UnlitMaterial(color: UIColor(red: 0.91, green: 0.69, blue: 0.36, alpha: 1))]
            ))
        }
        let inclination = Float(EarthOrbitConstants.tiangongInclinationDegrees * .pi / 180)
        orbit.orientation = simd_quatf(angle: inclination, axis: SIMD3(1, 0, 0))
        root.addChild(orbit)
        orbitNode = orbit

        let tiangong = Entity()
        tiangong.name = "tiangong"
        tiangong.components.set(ModelComponent(
            mesh: MeshResource.generateBox(size: SIMD3(0.05, 0.02, 0.02)),
            materials: [UnlitMaterial(color: UIColor(red: 0.95, green: 0.85, blue: 0.55, alpha: 1))]
        ))
        root.addChild(tiangong)
        tiangongNode = tiangong

        let track = Entity()
        track.name = "groundTrack"
        root.addChild(track)
        trackNode = track
        rebuildGroundTrack()

        let light = Entity()
        light.name = "sunLight"
        let directional = DirectionalLightComponent(
            color: UIColor(white: 1, alpha: 1),
            intensity: 8000,
            isRealWorldProxy: false
        )
        light.components.set(directional)
        root.addChild(light)
        sunLight = light
    }

    private func rebuildGroundTrack() {
        guard let trackNode else { return }
        trackNode.children.removeAll()
        var positions: [SIMD3<Float>] = []
        for step in 0...240 {
            let phase = Double(step) / 240
            let track = EarthOrbitGeometry.groundTrack(phase: phase)
            let lat = track.latitudeDegrees * .pi / 180
            let lon = track.longitudeDegrees * .pi / 180
            let r = EarthOrbitGeometry.earthDisplayRadius * 1.002
            positions.append(SIMD3(
                Float(cos(lat) * cos(lon)) * r,
                Float(sin(lat)) * r,
                Float(-cos(lat) * sin(lon)) * r
            ))
        }
        for index in 0..<positions.count - 1 {
            let segment = Entity()
            segment.name = "track.\(index)"
            let a = positions[index]
            let b = positions[index + 1]
            let length = simd_distance(a, b)
            guard length > 0.0001, length < 0.2 else { continue }
            segment.components.set(ModelComponent(
                mesh: MeshResource.generateBox(size: SIMD3(0.004, 0.004, length)),
                materials: [UnlitMaterial(color: UIColor(white: 0.55, alpha: 1))]
            ))
            segment.position = (a + b) / 2
            segment.look(at: b, from: segment.position, relativeTo: nil)
            trackNode.addChild(segment)
        }
    }

    func attach(_ content: RealityViewCameraContent) {
        self.content = content
    }

    func apply(julianDay: Double, phase: Double, rig: OrbitRig, stop: EarthOrbitCameraStop) {
        moonNode?.position = EarthOrbitGeometry.moonPosition(julianDay: julianDay)
        tiangongNode?.position = EarthOrbitGeometry.tiangongPosition(phase: phase)
        let sun = EarthOrbitGeometry.sunDirection(julianDay: julianDay)
        sunLight?.look(at: sun * 100, from: .zero, relativeTo: nil)
        orbitNode?.isEnabled = stop == .orbitClose
        trackNode?.isEnabled = stop == .orbitClose
        if let cameraEntity {
            let position = rig.cameraPosition()
            let stopChanged = lastStop != nil && lastStop != stop
            lastStop = stop
            if let transitionEnd {
                if stopChanged {
                    self.transitionEnd = nil
                } else if ProcessInfo.processInfo.systemUptime < transitionEnd {
                    return
                } else {
                    self.transitionEnd = nil
                }
            }
            if stopChanged {
                transitionEnd = ProcessInfo.processInfo.systemUptime + EarthOrbitCameraStop.transitionDuration
                var transform = cameraEntity.transform
                transform.translation = position
                let forward = simd_normalize(-position)
                let right = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))
                let up = simd_cross(right, forward)
                transform.rotation = simd_quatf(simd_float3x3(columns: (right, up, -forward)))
                cameraEntity.move(
                    to: transform,
                    relativeTo: nil,
                    duration: EarthOrbitCameraStop.transitionDuration,
                    timingFunction: .easeInOut
                )
            } else {
                cameraEntity.position = position
                cameraEntity.look(at: .zero, from: position, relativeTo: nil)
            }
        }
    }

    func screenPoint(of name: String) -> CGPoint? {
        guard let content else { return nil }
        let node: Entity?
        switch name {
        case "earth": node = earthNode
        case "moon": node = moonNode
        case "tiangong": node = tiangongNode
        default: node = nil
        }
        guard let node else { return nil }
        return content.project(point: node.position(relativeTo: nil), to: Self.space)
    }

    func pick(at point: CGPoint) -> String? {
        guard let content else { return nil }
        var best: (name: String, distance: CGFloat)?
        for (name, node) in [("earth", earthNode), ("moon", moonNode), ("tiangong", tiangongNode)] {
            guard let node,
                  let projected = content.project(point: node.position(relativeTo: nil), to: Self.space)
            else { continue }
            let distance = hypot(projected.x - point.x, projected.y - point.y)
            let threshold: CGFloat = name == "tiangong" ? 44 : 60
            guard distance <= threshold else { continue }
            if best == nil || distance < best!.distance {
                best = (name, distance)
            }
        }
        return best?.name
    }
}
