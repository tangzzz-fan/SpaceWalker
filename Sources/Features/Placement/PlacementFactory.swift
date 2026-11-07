import RealityKit
import UIKit

enum PlacementFactory {
    static let cubeName = "placeholderCube"
    static let reticleName = "reticle"

    static func makeReticle() -> Entity {
        let mesh = MeshResource.generateCylinder(height: 0.002, radius: 0.035)
        var material = UnlitMaterial(color: UIColor.systemOrange.withAlphaComponent(0.85))
        material.blending = .transparent(opacity: 0.85)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = reticleName
        return entity
    }

    static func makeCube() -> Entity {
        let mesh = MeshResource.generateBox(size: PlacementMath.cubeHeight, cornerRadius: 0.006)
        let material = SimpleMaterial(
            color: UIColor.systemTeal,
            roughness: 0.4,
            isMetallic: false
        )
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = cubeName
        return entity
    }

    static func makeShadow() -> Entity {
        let mesh = MeshResource.generatePlane(width: 0.16, depth: 0.16, cornerRadius: 0.06)
        var material = UnlitMaterial(color: UIColor.black.withAlphaComponent(0.18))
        material.blending = .transparent(opacity: 0.18)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "contactShadow"
        return entity
    }
}
