import Foundation
import Observation
import RealityKit
import SwiftUI
import TGReduxKit

@MainActor
@Observable
final class ScaleTransitionEngine {
    var progress: Double = 1
    var readingMeters: Double = ScaleLevel.defaultLevel.representativeMeters
    var isTransitioning = false
    private(set) var outgoing: ScaleLevel?

    @ObservationIgnored var skySession: SkySession?
    @ObservationIgnored var solarScene: SolarSystemScene?
    @ObservationIgnored var earthScene: EarthOrbitScene?
    @ObservationIgnored var tiangongSession: TiangongSession?
    @ObservationIgnored var solarRig = OrbitRig()
    @ObservationIgnored var earthRig = EarthOrbitCameraStop.overview.rig
    @ObservationIgnored var earthStop: EarthOrbitCameraStop = .overview
    @ObservationIgnored var earthPhase: Double = 0
    @ObservationIgnored var solarJulianDay: Double = Ephemeris.julianDay(utc: Date())
    @ObservationIgnored var solarShowsOrbits = true
    @ObservationIgnored var solarSelected: BodyID?
    @ObservationIgnored var solarTrueScale = false

    @ObservationIgnored private var fromLevel: ScaleLevel = .sky
    @ObservationIgnored private var toLevel: ScaleLevel = .sky
    @ObservationIgnored private var startedAt: TimeInterval = 0
    @ObservationIgnored private var fromMeters: Double = ScaleLevel.defaultLevel.representativeMeters
    @ObservationIgnored private var toMeters: Double = ScaleLevel.defaultLevel.representativeMeters
    @ObservationIgnored private var fromFov: Float = SkyScene.defaultFieldOfView
    @ObservationIgnored private var toFov: Float = SkyScene.defaultFieldOfView
    @ObservationIgnored private var fromSolarRig = OrbitRig()
    @ObservationIgnored private var toSolarRig = OrbitRig()
    @ObservationIgnored private var fromEarthRig = OrbitRig()
    @ObservationIgnored private var toEarthRig = OrbitRig()
    @ObservationIgnored private var fromTiangongRig = TiangongRig()
    @ObservationIgnored private var toTiangongRig = TiangongRig()
    @ObservationIgnored private var samples: [Double] = []
    @ObservationIgnored private var token = 0
    @ObservationIgnored private var frames = FrameRateBox()
    @ObservationIgnored private var subscription: EventSubscription?

    static var duration: Double {
        LaunchMode.scaleTransitionDuration(environment: ProcessInfo.processInfo.environment)
            ?? ChromeTokens.cameraDuration
    }

    static let skyHandoffFieldOfView: Float = 55

    func attachFrameProbe(_ content: RealityViewCameraContent) {
        guard subscription == nil else { return }
        let box = frames
        subscription = content.subscribe(to: SceneEvents.Update.self) { event in
            box.append(event.deltaTime)
        }
    }

    func begin(_ request: ScaleTransitionRequest) {
        guard request.token != token else { return }
        token = request.token
        if isTransitioning {
            finish(commit: false)
        }
        fromLevel = request.from
        toLevel = request.to
        fromMeters = readingMeters
        toMeters = request.to.representativeMeters
        captureEndpoints()
        samples = []
        startedAt = ProcessInfo.processInfo.systemUptime
        isTransitioning = true
        outgoing = request.from
        progress = 0
        if request.from == .sky {
            skySession?.setFollowsAttitude(false)
        }
        SessionLog.append("scale.transition begin from=\(request.from) to=\(request.to) token=\(request.token)")
    }

    func tick(now: TimeInterval) {
        advanceEarthPhase(now: now)
        guard isTransitioning else { return }
        let linear = min(max((now - startedAt) / Self.duration, 0), 1)
        let eased = ScaleRuler.easeInOutCubic(linear)
        progress = eased
        readingMeters = ScaleRuler.readingMeters(fromMeters: fromMeters, toMeters: toMeters, progress: eased)
        samples.append(readingMeters)
        #if DEBUG
        let applyStart = ProcessInfo.processInfo.systemUptime
        #endif
        applyInterpolation(eased)
        #if DEBUG
        if LaunchMode.transitionTickDiagnostics(environment: ProcessInfo.processInfo.environment) {
            let applyMs = (ProcessInfo.processInfo.systemUptime - applyStart) * 1000
            let gapMs = lastTickUptime > 0 ? (now - lastTickUptime) * 1000 : 0
            SessionLog.append(String(
                format: "scale.tick token=%d p=%.3f gapMs=%.1f applyMs=%.1f",
                token, eased, gapMs, applyMs
            ))
        }
        lastTickUptime = now
        #endif
        if linear >= 1 {
            finish(commit: true)
        }
    }

    #if DEBUG
    @ObservationIgnored private var lastTickUptime: TimeInterval = 0
    #endif

    func opacity(for level: ScaleLevel) -> Double {
        guard isTransitioning else { return 1 }
        let deeperIsTarget = toLevel.depth > fromLevel.depth
        if deeperIsTarget {
            if level == toLevel { return max(progress, Self.hiddenOpacity) }
            if level == outgoing { return 1 }
        } else {
            if level == toLevel { return 1 }
            if level == outgoing { return max(1 - progress, Self.hiddenOpacity) }
        }
        return Self.hiddenOpacity
    }

    /// 见 ContentView.hiddenLayerOpacity：渐入层从 0 起步会触发 GPU 资源重建。
    private static let hiddenOpacity: Double = 0.002

    func isInteractive(_ level: ScaleLevel, route: ScaleLevel) -> Bool {
        !isTransitioning && level == route
    }

    func entryRig(for level: ScaleLevel, from: ScaleLevel) -> OrbitRig {
        from.handoffRig
    }

    func entryTiangongRig(from: ScaleLevel) -> TiangongRig {
        TiangongRig(
            yaw: from.handoffRig.yaw,
            pitch: from.handoffRig.pitch,
            distance: Self.tiangongEntryDistance(from: from)
        )
    }

    static func tiangongEntryDistance(from: ScaleLevel) -> Float {
        let handoff = from.handoffRig.distance
        let span = OrbitRig.distanceRange.upperBound - OrbitRig.distanceRange.lowerBound
        let normalized = (handoff - OrbitRig.distanceRange.lowerBound) / span
        let target = TiangongRig.distanceRange.lowerBound
            + normalized * (TiangongRig.distanceRange.upperBound - TiangongRig.distanceRange.lowerBound)
        return min(max(target, TiangongRig.distanceRange.lowerBound), TiangongRig.distanceRange.upperBound)
    }

    private func captureEndpoints() {
        let skyFov = skySession?.scene.fieldOfView ?? SkyScene.defaultFieldOfView
        let skyBase = skySession?.scene.baseFieldOfView ?? SkyScene.defaultFieldOfView
        switch (fromLevel, toLevel) {
        case (.sky, _):
            fromFov = skyFov
            toFov = Self.skyHandoffFieldOfView
        case (_, .sky):
            fromFov = Self.skyHandoffFieldOfView
            toFov = skyBase
        default:
            fromFov = Self.skyHandoffFieldOfView
            toFov = Self.skyHandoffFieldOfView
        }

        if fromLevel == .solar {
            fromSolarRig = solarRig
        } else {
            fromSolarRig = fromLevel.handoffRig
            solarRig = fromSolarRig
        }
        toSolarRig = toLevel == .solar ? OrbitRig() : toLevel.handoffRig

        if fromLevel == .earthOrbit {
            fromEarthRig = earthRig
        } else {
            fromEarthRig = fromLevel.handoffRig
            earthRig = fromEarthRig
        }
        toEarthRig = toLevel == .earthOrbit ? EarthOrbitCameraStop.overview.rig : toLevel.handoffRig
        earthStop = .overview

        if fromLevel == .tiangong {
            fromTiangongRig = tiangongSession?.rig ?? TiangongRig()
        } else {
            fromTiangongRig = entryTiangongRig(from: fromLevel)
            tiangongSession?.rig = fromTiangongRig
            tiangongSession?.applyRig()
        }
        toTiangongRig = toLevel == .tiangong ? TiangongRig() : entryTiangongRig(from: toLevel)
    }

    private func applyInterpolation(_ p: Double) {
        let f = Float(p)
        if fromLevel == .sky || toLevel == .sky {
            skySession?.setFieldOfView(fromFov + (toFov - fromFov) * f)
        }
        if fromLevel == .solar || toLevel == .solar {
            solarRig = Self.lerp(fromSolarRig, toSolarRig, f)
            solarScene?.apply(
                julianDay: solarJulianDay,
                showsOrbits: solarShowsOrbits,
                rig: solarRig,
                selected: solarSelected,
                trueScale: solarTrueScale
            )
        }
        if fromLevel == .earthOrbit || toLevel == .earthOrbit {
            earthRig = Self.lerp(fromEarthRig, toEarthRig, f)
            earthScene?.apply(julianDay: solarJulianDay, phase: earthPhase, rig: earthRig, stop: earthStop)
        }
        if fromLevel == .tiangong || toLevel == .tiangong {
            let rig = TiangongRig(
                yaw: fromTiangongRig.yaw + (toTiangongRig.yaw - fromTiangongRig.yaw) * f,
                pitch: fromTiangongRig.pitch + (toTiangongRig.pitch - fromTiangongRig.pitch) * f,
                distance: fromTiangongRig.distance + (toTiangongRig.distance - fromTiangongRig.distance) * f
            )
            tiangongSession?.rig = rig
            tiangongSession?.applyRig()
        }
    }

    private func finish(commit: Bool) {
        if commit {
            progress = 1
            readingMeters = toMeters
            applyInterpolation(1)
        }
        let violations = Self.monotonicViolations(samples, descending: toMeters < fromMeters)
        let fps = frames.snapshot()
        SessionLog.append(String(
            format: "scale.transition end from=%@ to=%@ samples=%d violations=%d avg=%.1f min=%.1f hitches=%d",
            String(describing: fromLevel), String(describing: toLevel), samples.count, violations,
            fps.averageFPS, fps.minimumFPS, fps.hitchCount
        ))
        let chunks = stride(from: 0, to: samples.count, by: 24).map {
            samples[$0..<min($0 + 24, samples.count)].map { String(format: "%.4e", $0) }.joined(separator: ",")
        }
        for (i, chunk) in chunks.enumerated() {
            SessionLog.append("scale.readings.\(token).\(i) \(chunk)")
        }
        isTransitioning = false
        outgoing = nil
        samples = []
        if commit, toLevel == .sky {
            skySession?.setFollowsAttitude(true)
        }
    }

    static func monotonicViolations(_ values: [Double], descending: Bool) -> Int {
        zip(values, values.dropFirst()).reduce(0) { count, pair in
            let (a, b) = pair
            let bad = descending ? b > a : b < a
            return count + (bad ? 1 : 0)
        }
    }

    static func lerp(_ a: OrbitRig, _ b: OrbitRig, _ t: Float) -> OrbitRig {
        OrbitRig(
            yaw: a.yaw + (b.yaw - a.yaw) * t,
            pitch: a.pitch + (b.pitch - a.pitch) * t,
            distance: a.distance + (b.distance - a.distance) * t
        )
    }

    private var lastEarthTick: TimeInterval = 0

    private func advanceEarthPhase(now: TimeInterval) {
        defer { lastEarthTick = now }
        guard lastEarthTick > 0 else { return }
        let delta = min(max(now - lastEarthTick, 0), 0.2)
        earthPhase += delta / 20
        if earthPhase >= 1 { earthPhase -= 1 }
    }
}