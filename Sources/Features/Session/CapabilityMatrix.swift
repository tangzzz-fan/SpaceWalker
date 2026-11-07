import Foundation

enum CapabilityMode: String, Equatable, Sendable {
    case full
    case degraded
}

enum DegradationReason: String, CaseIterable, Equatable, Sendable {
    case cameraUnauthorized
    case worldTrackingUnavailable
    case planeAnchorUnavailable
    case surfaceCollisionUnavailable
    case occlusionUnavailable
    case shadowUnavailable

    var displayName: String {
        switch self {
        case .cameraUnauthorized: "相机未授权"
        case .worldTrackingUnavailable: "无世界追踪"
        case .planeAnchorUnavailable: "无平面锚定"
        case .surfaceCollisionUnavailable: "无表面命中"
        case .occlusionUnavailable: "无现实遮挡"
        case .shadowUnavailable: "无阴影"
        }
    }
}

enum PlacementStrategy: String, Equatable, Sendable {
    case surfaceHit
    case planeCenter
    case unavailable
}

struct CapabilityMatrix: Equatable, Sendable {
    var mode: CapabilityMode
    var reasons: [DegradationReason]
    var canAnchorToPlanes: Bool
    var canHitRealSurfaces: Bool

    var isDegraded: Bool {
        mode == .degraded
    }

    var headline: String? {
        isDegraded ? "降级模式" : nil
    }

    var detail: String? {
        reasons.isEmpty ? nil : reasons.map(\.displayName).joined(separator: " · ")
    }

    var placementStrategy: PlacementStrategy {
        if canHitRealSurfaces { return .surfaceHit }
        if canAnchorToPlanes { return .planeCenter }
        return .unavailable
    }

    static let full = CapabilityMatrix(
        mode: .full,
        reasons: [],
        canAnchorToPlanes: true,
        canHitRealSurfaces: true
    )
}

enum CapabilityMatrixBuilder {
    static func make(
        requested: SessionRequirements,
        unavailability: SessionUnavailability
    ) -> CapabilityMatrix {
        var reasons: [DegradationReason] = []

        if !unavailability.cameraAuthorized {
            reasons.append(.cameraUnauthorized)
        }
        if requested.anchors.contains(.world), unavailability.anchors.contains(.world) {
            reasons.append(.worldTrackingUnavailable)
        }
        if requested.anchors.contains(.plane), unavailability.anchors.contains(.plane) {
            reasons.append(.planeAnchorUnavailable)
        }
        if requested.sceneUnderstanding.contains(.collision),
           unavailability.sceneUnderstanding.contains(.collision) {
            reasons.append(.surfaceCollisionUnavailable)
        }
        if requested.sceneUnderstanding.contains(.occlusion),
           unavailability.sceneUnderstanding.contains(.occlusion) {
            reasons.append(.occlusionUnavailable)
        }
        if requested.sceneUnderstanding.contains(.shadow),
           unavailability.sceneUnderstanding.contains(.shadow) {
            reasons.append(.shadowUnavailable)
        }

        let planesAvailable = requested.anchors.contains(.plane)
            && !unavailability.anchors.contains(.plane)
        let surfacesAvailable = requested.sceneUnderstanding.contains(.collision)
            && !unavailability.sceneUnderstanding.contains(.collision)

        return CapabilityMatrix(
            mode: reasons.isEmpty ? .full : .degraded,
            reasons: reasons,
            canAnchorToPlanes: planesAvailable,
            canHitRealSurfaces: surfacesAvailable
        )
    }

    static func make(from outcome: SessionOutcome) -> CapabilityMatrix {
        make(requested: outcome.requested, unavailability: outcome.unavailability)
    }
}
