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
    private var planeAnchor: AnchorEntity?
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

    var hasPlacement: Bool {
        cube != nil
    }

    private(set) var debugLine: String?

    func attach(_ content: RealityViewCameraContent) {
        self.content = content

        let anchor = AnchorEntity(
            plane: .horizontal,
            classification: .any,
            minimumBounds: [0.1, 0.1]
        )
        content.add(anchor)

        let reticle = PlacementFactory.makeReticle()
        reticle.isEnabled = false
        anchor.addChild(reticle)

        planeAnchor = anchor
        self.reticle = reticle
        logger.notice("placement attached")
    }

    func detach() {
        content = nil
        planeAnchor = nil
        reticle = nil
        cube = nil
        shadow = nil
        placedAnchorPosition = nil
    }

    func tick(center: CGPoint, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let content, let planeAnchor, let reticle else { return }

        guard planeAnchor.isAnchored else {
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
            reticle.position = planeAnchor.convert(position: lifted, from: nil)
            reticle.orientation = PlacementMath.orientation(normal: hit.normal)
            reticle.isEnabled = true
        } else {
            reticle.isEnabled = false
        }

        if let baseline = placedAnchorPosition {
            let drift = PlacementMath.drift(
                from: baseline,
                to: planeAnchor.position(relativeTo: nil)
            )
            if abs(drift - lastReportedDrift) > 0.005 {
                lastReportedDrift = drift
                onDriftMeasured?(drift)
            }
        }
    }

    func place(center: CGPoint) {
        guard cube == nil,
              let content,
              let planeAnchor,
              let hit = hit(center: center, content: content)
        else { return }

        let cube = PlacementFactory.makeCube()
        cube.position = planeAnchor.convert(
            position: PlacementMath.snappedCenter(hit: hit.position, normal: hit.normal),
            from: nil
        )
        cube.orientation = PlacementMath.orientation(normal: hit.normal)
        planeAnchor.addChild(cube)

        let shadow = PlacementFactory.makeShadow()
        shadow.position = planeAnchor.convert(
            position: hit.position + PlacementMath.surfaceNormal(hit.normal) * 0.001,
            from: nil
        )
        shadow.orientation = PlacementMath.orientation(normal: hit.normal)
        planeAnchor.addChild(shadow)

        placedAnchorPosition = planeAnchor.position(relativeTo: nil)
        debugLine = String(
            format: "hit(%.2f,%.2f,%.2f) n(%.2f,%.2f,%.2f)",
            hit.position.x, hit.position.y, hit.position.z,
            hit.normal.x, hit.normal.y, hit.normal.z
        )
        self.cube = cube
        self.shadow = shadow
        setReplaceNeeded(false)
        onPlaced?()

        logger.notice("placed hit=\(hit.position.debugDescription, privacy: .public)")
        #if DEBUG
        NSLog(
            "[SpaceWalker] placed x=%.3f y=%.3f z=%.3f n=(%.2f,%.2f,%.2f)",
            hit.position.x, hit.position.y, hit.position.z,
            hit.normal.x, hit.normal.y, hit.normal.z
        )
        #endif
    }

    func reset() {
        cube?.removeFromParent()
        shadow?.removeFromParent()
        cube = nil
        shadow = nil
        placedAnchorPosition = nil
        lastSurfaceHit = ProcessInfo.processInfo.systemUptime
        setReplaceNeeded(false)
        logger.notice("placement reset")
    }

    private func hit(center: CGPoint, content: RealityViewCameraContent) -> CollisionCastHit? {
        content
            .hitTest(point: center, in: Self.space, query: .nearest, mask: .all)
            .first { $0.entity.name != PlacementFactory.reticleName }
    }

    private func setSurface(_ available: Bool) {
        guard surfaceAvailable != available else { return }
        surfaceAvailable = available
        onSurfaceChanged?(available)
    }

    private func setReplaceNeeded(_ needed: Bool) {
        guard replaceNeeded != needed else { return }
        replaceNeeded = needed
        onReplaceNeeded?(needed)
    }
}
