import AVFoundation
import os
@preconcurrency import RealityKit

@MainActor
final class SessionRunner {
    private let session = SpatialTrackingSession()
    private let logger = Logger(subsystem: "com.tango.spacewalker", category: "session")
    private var isRunning = false

    func start(forcedUnavailability: SessionUnavailability = SessionUnavailability()) async -> SessionOutcome {
        SessionLog.append(
            "session.request anchors=\(Self.describe(SessionPlan.m0.anchors))"
                + " scene=\(Self.describe(SessionPlan.m0.sceneUnderstanding))"
                + " camera=\(SessionPlan.m0.camera.rawValue)"
        )

        guard await cameraAccessGranted() else {
            logger.error("camera access denied or restricted")
            let outcome = SessionPlan.outcome(
                for: SessionPlan.m0,
                unavailability: SessionUnavailability(cameraAuthorized: false),
                startedInMilliseconds: AppClock.elapsedMilliseconds()
            )
            SessionLog.append("session.denied camera=unauthorized elapsedMs=\(outcome.startedInMilliseconds)")
            return outcome
        }

        let unavailable = await session.run(Self.configuration(for: SessionPlan.m0))
        isRunning = true

        let outcome = SessionPlan.outcome(
            for: SessionPlan.m0,
            unavailability: Self.merge(
                Self.unavailability(from: unavailable),
                forcedUnavailability
            ),
            startedInMilliseconds: AppClock.elapsedMilliseconds()
        )

        let matrix = CapabilityMatrixBuilder.make(from: outcome)
        SessionLog.append(
            "session.started elapsedMs=\(outcome.startedInMilliseconds)"
                + " grantedAnchors=\(Self.describe(outcome.requirements.anchors))"
                + " grantedScene=\(Self.describe(outcome.requirements.sceneUnderstanding))"
                + " unavailableAnchors=\(Self.describe(outcome.unavailability.anchors))"
                + " unavailableScene=\(Self.describe(outcome.unavailability.sceneUnderstanding))"
                + " cameraAuthorized=\(outcome.unavailability.cameraAuthorized)"
        )
        SessionLog.append(
            "session.matrix mode=\(matrix.mode.rawValue)"
                + " reasons=\(matrix.reasons.map(\.rawValue).joined(separator: ","))"
                + " strategy=\(matrix.placementStrategy.rawValue)"
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

    private static func merge(
        _ base: SessionUnavailability,
        _ forced: SessionUnavailability
    ) -> SessionUnavailability {
        SessionUnavailability(
            anchors: base.anchors.union(forced.anchors),
            sceneUnderstanding: base.sceneUnderstanding.union(forced.sceneUnderstanding),
            cameraAuthorized: base.cameraAuthorized && forced.cameraAuthorized
        )
    }

    private static func describe<T: RawRepresentable & Hashable>(_ set: Set<T>) -> String where T.RawValue == String {
        set.map(\.rawValue).sorted().joined(separator: ",")
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
