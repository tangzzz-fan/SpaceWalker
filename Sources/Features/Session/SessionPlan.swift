import Foundation

enum TrackingAnchor: String, CaseIterable, Sendable {
    case world
    case plane
    case camera
}

enum SceneUnderstandingKind: String, CaseIterable, Sendable {
    case shadow
    case occlusion
    case collision
}

enum CameraPosition: String, Sendable {
    case back
    case front
}

struct SessionRequirements: Equatable, Sendable {
    var anchors: Set<TrackingAnchor>
    var sceneUnderstanding: Set<SceneUnderstandingKind>
    var camera: CameraPosition
}

struct SessionUnavailability: Equatable, Sendable {
    var anchors: Set<TrackingAnchor> = []
    var sceneUnderstanding: Set<SceneUnderstandingKind> = []
    var cameraAuthorized = true
}

struct SessionOutcome: Equatable, Sendable {
    var requested: SessionRequirements
    var requirements: SessionRequirements
    var unavailability: SessionUnavailability
    var startedInMilliseconds = 0

    var isUsable: Bool {
        requirements.anchors.contains(.world) && unavailability.cameraAuthorized
    }
}

enum SessionPlan {
    static let m0 = SessionRequirements(
        anchors: [.world, .plane, .camera],
        sceneUnderstanding: [.collision, .shadow, .occlusion],
        camera: .back
    )

    static func reduced(
        _ requirements: SessionRequirements,
        by unavailability: SessionUnavailability
    ) -> SessionRequirements {
        var result = requirements
        result.anchors.subtract(unavailability.anchors)
        result.sceneUnderstanding.subtract(unavailability.sceneUnderstanding)
        return result
    }

    static func outcome(
        for requirements: SessionRequirements,
        unavailability: SessionUnavailability,
        startedInMilliseconds: Int = 0
    ) -> SessionOutcome {
        SessionOutcome(
            requested: requirements,
            requirements: reduced(requirements, by: unavailability),
            unavailability: unavailability,
            startedInMilliseconds: startedInMilliseconds
        )
    }
}
