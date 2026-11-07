import AVFoundation
import os
@preconcurrency import RealityKit

@MainActor
final class SessionRunner {
    private let session = SpatialTrackingSession()
    private let logger = Logger(subsystem: "com.tango.spacewalker", category: "session")
    private var isRunning = false

    func start() async -> SessionOutcome {
        guard await cameraAccessGranted() else {
            logger.error("camera access denied or restricted")
            return SessionPlan.outcome(
                for: SessionPlan.m0,
                unavailability: SessionUnavailability(cameraAuthorized: false),
                startedInMilliseconds: AppClock.elapsedMilliseconds()
            )
        }

        let unavailable = await session.run(Self.configuration(for: SessionPlan.m0))
        isRunning = true

        let outcome = SessionPlan.outcome(
            for: SessionPlan.m0,
            unavailability: Self.unavailability(from: unavailable),
            startedInMilliseconds: AppClock.elapsedMilliseconds()
        )
        logger.notice(
            """
            session started anchors=\(outcome.requirements.anchors.count, privacy: .public) \
            sceneUnderstanding=\(outcome.requirements.sceneUnderstanding.count, privacy: .public) \
            unavailableAnchors=\(outcome.unavailability.anchors.count, privacy: .public) \
            missingCameraAuthorization=\(!outcome.unavailability.cameraAuthorized, privacy: .public) \
            elapsedMs=\(outcome.startedInMilliseconds, privacy: .public)
            """
        )
        #if DEBUG
        NSLog(
            "[SpaceWalker] session started elapsedMs=%d anchors=%d scene=%d unavailableAnchors=%d cameraAuthorized=%d",
            outcome.startedInMilliseconds,
            outcome.requirements.anchors.count,
            outcome.requirements.sceneUnderstanding.count,
            outcome.unavailability.anchors.count,
            outcome.unavailability.cameraAuthorized ? 1 : 0
        )
        #endif
        return outcome
    }

    func stop() async {
        guard isRunning else { return }
        await session.stop()
        isRunning = false
        logger.notice("session stopped")
    }

    private func cameraAccessGranted() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private static func configuration(
        for requirements: SessionRequirements
    ) -> SpatialTrackingSession.Configuration {
        var anchors: Set<SpatialTrackingSession.Configuration.AnchorCapability> = []
        for anchor in requirements.anchors {
            switch anchor {
            case .world:
                anchors.insert(.world)
            case .plane:
                anchors.insert(.plane)
            case .camera:
                anchors.insert(.camera)
            }
        }

        var understanding: Set<SpatialTrackingSession.Configuration.SceneUnderstandingCapability> = []
        for kind in requirements.sceneUnderstanding {
            switch kind {
            case .shadow:
                understanding.insert(.shadow)
            case .occlusion:
                understanding.insert(.occlusion)
            case .collision:
                understanding.insert(.collision)
            }
        }

        return SpatialTrackingSession.Configuration(
            tracking: anchors,
            sceneUnderstanding: understanding,
            camera: requirements.camera == .back ? .back : .front
        )
    }

    private static func unavailability(
        from raw: SpatialTrackingSession.UnavailableCapabilities?
    ) -> SessionUnavailability {
        guard let raw else { return SessionUnavailability() }

        var result = SessionUnavailability()
        for anchor in raw.anchor {
            if anchor == .world {
                result.anchors.insert(.world)
            } else if anchor == .plane {
                result.anchors.insert(.plane)
            } else if anchor == .camera {
                result.anchors.insert(.camera)
            }
        }

        for capability in raw.sceneUnderstanding {
            if capability == .shadow {
                result.sceneUnderstanding.insert(.shadow)
            } else if capability == .occlusion {
                result.sceneUnderstanding.insert(.occlusion)
            } else if capability == .collision {
                result.sceneUnderstanding.insert(.collision)
            }
        }

        result.cameraAuthorized = !(raw.missingCameraAuthorization ?? false)
        return result
    }
}
