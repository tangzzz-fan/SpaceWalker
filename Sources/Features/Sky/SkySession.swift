import Foundation
import RealityKit
import simd
import SwiftUI

@MainActor
@Observable
final class SkySession {
    @ObservationIgnored private(set) var scene = SkyScene()
    @ObservationIgnored private var rig = SkyRig()
    @ObservationIgnored private var attitude = DeviceAttitude()
    @ObservationIgnored private var zoomBase: Float = SkyScene.defaultFieldOfView
    @ObservationIgnored private var lastDrag: CGSize = .zero
    @ObservationIgnored private var rigBeforePinch: SkyRig?
    @ObservationIgnored private var isPinching = false
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init() {
        SessionLog.append("sky.session boot")
    }

    var catalog: StarCatalog?
    var selected: Star?
    var selectedGroup: SkyGroup?
    var groups: [SkyGroup] = []
    var tonight: [TonightPick] = []
    var showsConstellations = true
    var showsAsterisms = false
    var showsOutlines = false
    var showsPatterns = false
    var identifiedConstellation: Constellation?
    var identifiedPattern: SkyPattern?
    var guide: Star?
    var guideVector: GuideVector?
    var currentRegion: SkyRegion?
    var infoRegion: ConstellationRegion?
    var regionStamp: TimeInterval = 0
    var attention = AttentionArbiter()
    var observer = SkyObserver()
    var perf = SkyPerformanceProbe()
    var tonightStamp: TimeInterval = 0

    var isMotionActive: Bool { attitude.isAvailable }

    func startMotion(_ onUpdate: @escaping @MainActor () -> Void) {
        guard !attitude.isAvailable else { return }
        attitude.start { [weak self] orientation in
            guard let self else { return }
            scene.setAttitude(orientation)
            onUpdate()
        }
    }

    func stopMotion() {
        attitude.stop()
    }

    /// 后台循环没有结构化的生命周期，必须自己收：`.task` 只取消 `load()`，
    /// 里面 `Task { }` 建出来的是无主任务，页面走了它们还在按 80ms 转。
    func track(_ task: Task<Void, Never>) {
        tasks.append(task)
    }

    func pause() {
        SessionLog.append("sky.pause tasks=\(tasks.count)")
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        stopMotion()
    }

    /// 转屏会按高度比例改视场，捏合基准必须跟着走，
    /// 否则下次捏合会从旧值开始跳一下。
    func resize(_ size: CGSize) {
        scene.resize(size)
        zoomBase = scene.fieldOfView
    }

    func applyRig() {
        scene.apply(rig: rig)
    }

    func setFieldOfView(_ degrees: Float) {
        scene.setFieldOfView(degrees)
        zoomBase = scene.fieldOfView
    }

    func aim(at direction: SIMD3<Float>) {
        guard let aimed = scene.aim(at: direction) else { return }
        rig = aimed
    }

    func resetOrientation() {
        scene.releaseAim()
        rig = SkyRig()
    }

    func drag(to translation: CGSize) {
        // 姿态驱动或捏合时两根手指也有位移，不挡掉就会「缩放顺带把天空推走」。
        guard !attitude.isAvailable, !isPinching else {
            lastDrag = translation
            return
        }
        if lastDrag == .zero { rigBeforePinch = rig }
        scene.releaseAim()
        rig.drag(
            deltaX: Float(translation.width - lastDrag.width),
            deltaY: Float(translation.height - lastDrag.height)
        )
        lastDrag = translation
    }

    func endDrag() {
        lastDrag = .zero
        rigBeforePinch = nil
    }

    /// 捏合被识别前，拖动已经按两指位移把天空推了一段。退回捏合前的姿态，
    /// 缩放就只改视场，不动朝向。
    func magnify(_ magnification: CGFloat) {
        if !isPinching {
            isPinching = true
            if let snapshot = rigBeforePinch {
                rig = snapshot
                scene.apply(rig: snapshot)
                lastDrag = .zero
            }
        }
        scene.setFieldOfView(zoomBase / Float(magnification))
    }

    func endMagnify() {
        isPinching = false
        zoomBase = scene.fieldOfView
        lastDrag = .zero
        SessionLog.append(String(
            format: "sky.zoom fov=%.1f rig=%.2f,%.2f",
            scene.fieldOfView,
            rig.yaw,
            rig.pitch
        ))
    }

    /// 复位到「这个方向下的默认」，不是死板的 60°：横屏保尺度后默认是 31°。
    func resetZoom() {
        scene.setFieldOfView(scene.baseFieldOfView)
        zoomBase = scene.baseFieldOfView
        SessionLog.append(String(format: "sky.fov reset value=%.1f", scene.baseFieldOfView))
    }
}
