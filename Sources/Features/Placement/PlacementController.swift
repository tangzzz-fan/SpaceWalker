import Foundation
import os
import RealityKit
import SwiftUI

@MainActor
final class PlacementController {
    static let coordinateSpaceName = "reality"
    static let space = NamedCoordinateSpace.named(coordinateSpaceName)

    private let logger = Logger(subsystem: "com.tango.spacewalker", category: "placement")

    private var content: RealityViewCameraContent?
    private var matrix = CapabilityMatrix.full
    private var anchor: AnchorEntity?
    private var reticle: Entity?
    private var cube: Entity?
    private var shadow: Entity?
    private var placedAnchorPosition: SIMD3<Float>?
    private var lastReportedDrift: Float = 0
    private var lastSurfaceHit = ProcessInfo.processInfo.systemUptime
    private var surfaceAvailable = false
    private var replaceNeeded = false

    var onSurfaceChanged: ((Bool) -> Void)?
    var onPlaced: (() -> Void)?
    var onDriftMeasured: ((Float) -> Void)?
    var onReplaceNeeded: ((Bool) -> Void)?

    private(set) var debugLine: String?
    private(set) var anchorWorldPosition: SIMD3<Float>?

    func attach(_ content: RealityViewCameraContent) {
        self.content = content
        logger.notice("placement attached")
    }

    func apply(_ matrix: CapabilityMatrix) {
        guard let content else { return }
        self.matrix = matrix

        if anchor == nil {
            let anchor: AnchorEntity
            if matrix.canAnchorToPlanes {
                anchor = AnchorEntity(
                    plane: .horizontal,
                    classification: .any,
                    minimumBounds: [0.1, 0.1]
                )
            } else {
                anchor = AnchorEntity(world: .zero)
            }
            content.add(anchor)

            let reticle = PlacementFactory.makeReticle()
            reticle.isEnabled = false
            anchor.addChild(reticle)

            self.anchor = anchor
            self.reticle = reticle
        }

        SessionLog.append(
            "placement.apply strategy=\(matrix.placementStrategy.rawValue)"
                + " planes=\(matrix.canAnchorToPlanes)"
                + " surfaces=\(matrix.canHitRealSurfaces)"
        )
    }

    func detach() {
        content = nil
        anchor = nil
        reticle = nil
        cube = nil
        shadow = nil
        placedAnchorPosition = nil
    }

    func tick(center: CGPoint, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let content, let anchor, let reticle else { return }
        anchorWorldPosition = anchor.position(relativeTo: nil)

        switch matrix.placementStrategy {
        case .unavailable:
            reticle.isEnabled = false
            setSurface(false)

        case .planeCenter:
            guard anchor.isAnchored else {
                reticle.isEnabled = false
                setSurface(false)
                return
            }
            lastSurfaceHit = now
            setSurface(true)
            setReplaceNeeded(false)
            reticle.position = SIMD3(0, 0.001, 0)
            reticle.isEnabled = cube == nil
            measureDrift(anchor)

        case .surfaceHit:
            guard anchor.isAnchored else {
                reticle.isEnabled = false
                setSurface(false)
                return
            }

            guard let hit = hit(center: center, content: content) else {
                reticle.isEnabled = false
                setSurface(false)
                if placedAnchorPosition != nil,
                   PlacementRules.shouldPromptReplace(secondsSinceSurfaceHit: now - lastSurfaceHit) {
                    setReplaceNeeded(true)
                }
                return
            }

            lastSurfaceHit = now
            setSurface(true)
            setReplaceNeeded(false)

            if cube == nil {
                let lifted = hit.position + PlacementMath.surfaceNormal(hit.normal) * 0.001
                reticle.position = anchor.convert(position: lifted, from: nil)
                reticle.orientation = PlacementMath.orientation(normal: hit.normal)
                reticle.isEnabled = true
            } else {
                reticle.isEnabled = false
            }

            measureDrift(anchor)
        }
    }

    func place(center: CGPoint) {
        guard cube == nil, let anchor else { return }

        switch matrix.placementStrategy {
        case .unavailable:
            SessionLog.append("placement.blocked strategy=unavailable")
            return

        case .planeCenter:
            attachCube(
                at: SIMD3(0, PlacementMath.cubeHeight / 2, 0),
                orientation: simd_quatf(angle: 0, axis: SIMD3(0, 1, 0)),
                anchor: anchor,
                source: "planeCenter"
            )

        case .surfaceHit:
            guard let content, let hit = hit(center: center, content: content) else { return }
            let local = anchor.convert(
                position: PlacementMath.snappedCenter(hit: hit.position, normal: hit.normal),
                from: nil
            )
            debugLine = String(
                format: "hit(%.2f,%.2f,%.2f) n(%.2f,%.2f,%.2f)",
                hit.position.x, hit.position.y, hit.position.z,
                hit.normal.x, hit.normal.y, hit.normal.z
            )
            SessionLog.append(
                String(
                    format: "placement.placed source=surfaceHit hit=(%.3f,%.3f,%.3f) n=(%.2f,%.2f,%.2f)",
                    hit.position.x, hit.position.y, hit.position.z,
                    hit.normal.x, hit.normal.y, hit.normal.z
                )
            )
            attachCube(
                at: local,
                orientation: PlacementMath.orientation(normal: hit.normal),
                anchor: anchor,
                source: "surfaceHit"
            )
        }
    }

    func reset() {
        cube?.removeFromParent()
        shadow?.removeFromParent()
        cube = nil
        shadow = nil
        placedAnchorPosition = nil
        lastSurfaceHit = ProcessInfo.processInfo.systemUptime
        setReplaceNeeded(false)
        SessionLog.append("placement.reset")
        logger.notice("placement reset")
    }

    private func attachCube(
        at local: SIMD3<Float>,
        orientation: simd_quatf,
        anchor: AnchorEntity,
        source: String
    ) {
        let cube = PlacementFactory.makeCube()
        cube.position = local
        cube.orientation = orientation
        anchor.addChild(cube)

        let shadow = PlacementFactory.makeShadow()
        shadow.position = local + SIMD3(0, -PlacementMath.cubeHeight / 2 + 0.001, 0)
        shadow.orientation = orientation
        anchor.addChild(shadow)

        placedAnchorPosition = anchor.position(relativeTo: nil)
        self.cube = cube
        self.shadow = shadow
        setReplaceNeeded(false)
        onPlaced?()

        if source == "planeCenter" {
            debugLine = "degraded: planeCenter"
            SessionLog.append("placement.placed source=planeCenter degraded=true")
        }
        logger.notice("placed source=\(source, privacy: .public)")
    }

    private func measureDrift(_ anchor: AnchorEntity) {
        guard let baseline = placedAnchorPosition else { return }
        let drift = PlacementMath.drift(from: baseline, to: anchor.position(relativeTo: nil))
        if abs(drift - lastReportedDrift) > 0.005 {
            lastReportedDrift = drift
            onDriftMeasured?(drift)
        }
    }

    private func hit(center: CGPoint, content: RealityViewCameraContent) -> CollisionCastHit? {
        content
            .hitTest(point: center, in: Self.space, query: .all, mask: .all)
            .first {
                $0.entity.name != PlacementFactory.reticleName
                    && PlacementMath.isHorizontalSurface(normal: $0.normal)
            }
    }

    private func setSurface(_ available: Bool) {
        guard surfaceAvailable != available else { return }
        surfaceAvailable = available
        onSurfaceChanged?(available)
        SessionLog.append("placement.surface available=\(available)")
    }

    private func setReplaceNeeded(_ needed: Bool) {
        guard replaceNeeded != needed else { return }
        replaceNeeded = needed
        onReplaceNeeded?(needed)
    }
}
