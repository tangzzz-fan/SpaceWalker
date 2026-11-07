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

    var dockingActive = false
    var dockingOffset = SIMD3<Float>(0, 0, 0.42)
    var dockingOutcome: TiangongDocking.Outcome = .approaching
    var controlMode: TiangongDocking.ControlMode = .coarse
    var dockingElapsed: TimeInterval = 0
    var dockingHolding: TimeInterval = 0

    @ObservationIgnored private var lastDockingOffset: SIMD3<Float>?
    @ObservationIgnored var viewSize: CGSize = .zero
    @ObservationIgnored private var dragging: TiangongModuleID?
    @ObservationIgnored private var dragStart: SIMD3<Float> = .zero

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
        if LaunchMode.tiangongDockingOnLaunch(environment: ProcessInfo.processInfo.environment) {
            beginDocking()
        }
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

    /// 按下时决定这次手势是「拖模块」还是「转相机」。
    func beginModuleDrag(at point: CGPoint) -> Bool {
        guard let id = scene.pick(at: point), separated.contains(id) else { return false }
        dragging = id
        dragStart = scene.position(of: id) ?? TiangongLayout.restPosition(id)
        selected = id
        return true
    }

    func dragModule(translation: CGSize) {
        guard let dragging else { return }
        let basis = scene.cameraBasis()
        let scale = TiangongAssembly.metersPerPoint(
            distance: rig.distance,
            fieldOfViewDegrees: 50,
            screenHeight: viewSize.height
        )
        let offset = basis.right * Float(translation.width) * scale
            + basis.up * Float(-translation.height) * scale
        scene.setPosition(dragStart + offset, for: dragging)
    }

    /// 松手即判定。三条件任缺其一都不吸附，并沿给的方和推出一个可见的排斥。
    func endModuleDrag() {
        guard let id = dragging else { return }
        dragging = nil
        let position = scene.position(of: id) ?? TiangongLayout.restPosition(id)
        switch TiangongAssembly.verdict(module: id, at: position, port: id) {
        case .snap(let target):
            separated.remove(id)
            scene.setPosition(target, for: id)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            SessionLog.append("tiangong.assembly id=\(id.rawValue) snap=1")
        case .reject(let failure, let push):
            scene.push(id, direction: push)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            SessionLog.append("tiangong.assembly id=\(id.rawValue) reject=\(failure) reason=\(failure.message)")
        }
    }

    // MARK: - 对接

    func beginDocking() {
        separated.removeAll()
        scene.applySeparation(separated, animated: false)
        dockingActive = true
        dockingOffset = SIMD3(0, 0, 0.42)
        dockingOutcome = .approaching
        dockingElapsed = 0
        dockingHolding = 0
        lastDockingOffset = nil
        selected = nil
        applyShipPosition()
        SessionLog.append("tiangong.docking begin")
    }

    func endDocking() {
        dockingActive = false
        dockingOutcome = .approaching
        scene.setPosition(TiangongLayout.shenzhouCenter, for: .shenzhou)
        SessionLog.append("tiangong.docking end")
    }

    func toggleControlMode() {
        controlMode = controlMode == .coarse ? .fine : .coarse
        SessionLog.append("tiangong.docking mode=\(controlMode.rawValue)")
    }

    func moveShip(drag: CGSize, magnification: CGFloat) {
        guard dockingActive, !isTerminal else { return }
        let scale = TiangongAssembly.metersPerPoint(
            distance: rig.distance,
            fieldOfViewDegrees: 50,
            screenHeight: viewSize.height
        )
        let delta = TiangongDocking.offsetDelta(
            drag: drag,
            magnification: magnification,
            mode: controlMode,
            metersPerPoint: scale
        )
        dockingOffset += delta
        dockingOffset.x = min(max(dockingOffset.x, -0.25), 0.25)
        dockingOffset.y = min(max(dockingOffset.y, -0.25), 0.25)
        dockingOffset.z = min(max(dockingOffset.z, 0), 0.6)
        applyShipPosition()
    }

    func stepDocking(delta: TimeInterval) {
        guard dockingActive, !isTerminal else { return }
        dockingElapsed += delta
        let speed: Float = lastDockingOffset.map {
            simd_length(dockingOffset - $0) / Float(max(delta, 0.001))
        } ?? 0
        lastDockingOffset = dockingOffset

        let outcome = TiangongDocking.judge(
            TiangongDocking.Input(
                offset: dockingOffset,
                speed: speed,
                elapsed: dockingElapsed,
                holding: dockingHolding
            ),
            delta: delta
        )
        dockingOutcome = outcome

        switch outcome {
        case .holding(let value):
            dockingHolding = value
        case .docked:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            SessionLog.append("tiangong.docking docked elapsed=\(String(format: "%.1f", dockingElapsed))")
        case .failed(let failure):
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            SessionLog.append("tiangong.docking failed=\(failure.rawValue) reason=\(failure.message)")
        case .approaching:
            break
        }
    }

    func resetDocking() {
        beginDocking()
    }

    var isTerminal: Bool {
        switch dockingOutcome {
        case .docked, .failed: true
        default: false
        }
    }

    var dockingHeadline: String? {
        switch dockingOutcome {
        case .approaching:
            "轴向距离 " + TiangongFormat.meters(abs(dockingOffset.z))
        case .holding(let value):
            "已进入容差 · 保持 \(String(format: "%.1f", value)) s"
        case .docked:
            "对接成功"
        case .failed(let failure):
            "对接失败：" + failure.message
        }
    }

    private func applyShipPosition() {
        let halfLength = TiangongScale.display(TiangongModel.shenzhouLength) / 2
        scene.setPosition(
            SIMD3(dockingOffset.x, dockingOffset.y, TiangongLayout.dockingPortZ + dockingOffset.z + halfLength),
            for: .shenzhou
        )
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
