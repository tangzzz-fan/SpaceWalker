import Foundation
import Observation
import RealityKit
import UIKit
import SwiftUI

@MainActor
@Observable
final class TiangongSession {
    /// 场景与相机都是 60Hz 量或引用类型，进观察集合只会让 body 按手势频率重算。
    @ObservationIgnored let scene = TiangongScene()
    @ObservationIgnored var rig = TiangongRig(distance: LaunchMode.tiangongDistance(
        environment: ProcessInfo.processInfo.environment
    ) ?? TiangongRig().distance)
    @ObservationIgnored private var lastDrag: CGSize = .zero
    @ObservationIgnored private var lastMagnification: CGFloat = 1

    var selected: TiangongModuleID?
    var separated: Set<TiangongModuleID> = []

    init() {
        separated = LaunchMode.tiangongSeparated(environment: ProcessInfo.processInfo.environment)
        SessionLog.append("tiangong.session boot separated=\(separated.count)")
    }

    func applyLaunchState() {
        guard !separated.isEmpty else { return }
        scene.applySeparation(separated, animated: false)
        SessionLog.append("tiangong.disassembly restored=\(separated.count)")
    }

    func attach(_ content: RealityViewCameraContent) {
        scene.attach(content)
        scene.apply(rig: rig)
        applyLaunchState()
        SessionLog.append("tiangong.attach modules=\(TiangongModuleID.allCases.count)")
        SessionLog.append("tiangong.budget triangles=\(scene.triangleEstimate)")
    }

    func applyRig() {
        scene.apply(rig: rig)
    }

    func rotate(translation: CGSize) {
        rig.rotate(
            deltaX: Float(translation.width - lastDrag.width),
            deltaY: Float(translation.height - lastDrag.height)
        )
        lastDrag = translation
        scene.apply(rig: rig)
    }

    func endDrag() {
        lastDrag = .zero
    }

    func magnify(_ magnification: CGFloat) {
        rig.dolly(scale: Float(magnification / max(lastMagnification, 0.001)))
        lastMagnification = magnification
        scene.apply(rig: rig)
    }

    func endMagnify() {
        lastMagnification = 1
    }

    /// 常驻标签的锚点。062 的结论：几何本身认不出，靠标签把「这是什么」补上。
    func labelAnchors() -> [TiangongModuleID: CGPoint] {
        var anchors: [TiangongModuleID: CGPoint] = [:]
        for id in TiangongModuleID.allCases {
            if let point = scene.screenPoint(for: id) {
                anchors[id] = point
            }
        }
        return anchors
    }

    func pick(at point: CGPoint) {
        let hit = scene.pick(at: point)
        selected = hit
        SessionLog.append("tiangong.select id=\(hit?.rawValue ?? "none")")
    }

    func toggleDisassembly(_ id: TiangongModuleID) {
        guard TiangongDisassembly.isDismantlable(id) else { return }
        if separated.contains(id) {
            separated.remove(id)
        } else {
            separated.insert(id)
        }
        scene.applySeparation(separated, animated: true)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        SessionLog.append(
            "tiangong.disassembly id=\(id.rawValue) separated=\(separated.contains(id) ? 1 : 0)"
                + " total=\(separated.count)"
        )
    }

    func resetView() {
        rig = TiangongRig()
        selected = nil
        separated.removeAll()
        scene.applySeparation(separated, animated: true)
        scene.apply(rig: rig)
        SessionLog.append("tiangong.view reset")
    }
}
