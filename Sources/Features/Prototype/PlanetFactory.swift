import RealityKit
import UIKit

enum PlanetFactory {
    @MainActor
    static func makePlanet() -> Entity {
        let mesh = MeshResource.generateSphere(radius: 0.06)
        let material = SimpleMaterial(color: .orange, isMetallic: false)
        let planet = ModelEntity(mesh: mesh, materials: [material])
        planet.name = "planet"
        planet.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.06)]))
        planet.components.set(InputTargetComponent())
        return planet
    }
}
