import RealityKit
import SwiftUI
import simd

@MainActor
@Observable
final class ProbeModel {
    var sky = SkyScene()
    var solar = SolarSystemScene()
    var catalog: StarCatalog?
    var environment: RealityViewEnvironment?
    var attached = false
    var phase = "boot"
    var progress: Double = 0
    var rulerMeters = ScaleRuler.readingMeters(from: .sky, to: .solar, progress: 0)
    var readings: [Double] = []
    var solarRig = ScaleLevel.sky.handoffRig
    var solarAttached = false
    let frames = FrameRateBox()
    private var subscription: EventSubscription?
    private var running = false

    static let duration: Double = {
        if let raw = ProcessInfo.processInfo.environment["PROBE_SECONDS"], let v = Double(raw) { return v }
        return 0.45
    }()

    func loadAssets() {
        guard catalog == nil else { return }
        catalog = StarCatalog.loadFromBundle()
        environment = SpaceEnvironment.load()
        SessionLog.append("probe.assets stars=\(catalog?.stars.count ?? 0) env=\(environment != nil)")
    }

    func attach(_ content: RealityViewCameraContent) {
        guard !attached, let catalog else { return }
        attached = true
        sky.build(catalog: catalog)
        let jd = Ephemeris.julianDay(utc: Date())
        sky.buildBodies(julianDay: jd)
        sky.attach(content)
        content.add(sky.root)
        solar.build()
        solar.root.isEnabled = false
        solar.apply(julianDay: jd, showsOrbits: true, rig: solarRig, selected: nil)
        let frames = frames
        subscription = content.subscribe(to: SceneEvents.Update.self) { event in
            frames.append(event.deltaTime)
        }
        sky.setSource(.manual)
        sky.apply(rig: SkyRig())
        SessionLog.append("probe.attach")
    }

    func logRunReadings() {
        let mono = readings.isEmpty ? false : zip(readings, readings.dropFirst()).allSatisfy { $0.1 >= $0.0 || $0.1 <= $0.0 }
        let chunks = stride(from: 0, to: readings.count, by: 24).map {
            readings[$0..<min($0 + 24, readings.count)].map { String(format: "%.4e", $0) }.joined(separator: ",")
        }
        for (i, chunk) in chunks.enumerated() {
            SessionLog.append("probe.readings.\(phase).\(i) \(chunk)")
        }
        SessionLog.append("probe.readings.\(phase).summary n=\(readings.count) first=\(readings.first ?? 0) last=\(readings.last ?? 0)")
        _ = mono
    }

    func runRoundtrips(_ count: Int) async {
        guard attached, solarAttached, !running else { return }
        running = true
        for i in 1...count {
            await play(direction: 1, index: i)
            try? await Task.sleep(for: .milliseconds(400))
            await play(direction: -1, index: i)
            try? await Task.sleep(for: .milliseconds(400))
        }
        let sampler = frames.snapshot()
        SessionLog.append(String(
            format: "probe.fps avg=%.1f min=%.1f hitches=%d",
            sampler.averageFPS, sampler.minimumFPS, sampler.hitchCount
        ))
        SessionLog.append("probe.done readings=\(readings.count)")
        running = false
        phase = "done"
    }

    private func play(direction: Double, index: Int) async {
        readings = []
        phase = direction > 0 ? "descend.\(index)" : "ascend.\(index)"
        SessionLog.append("probe.\(phase) begin")
        solar.root.isEnabled = true
        let start = ProcessInfo.processInfo.systemUptime
        while true {
            let now = ProcessInfo.processInfo.systemUptime
            let linear = min((now - start) / Self.duration, 1)
            let eased = linear * linear * (3 - 2 * linear)
            let p = direction > 0 ? eased : 1 - eased
            progress = p
            apply(progress: p)
            let reading = ScaleRuler.readingMeters(from: .sky, to: .solar, progress: p)
            rulerMeters = reading
            readings.append(reading)
            if linear >= 1 { break }
            try? await Task.sleep(nanoseconds: 4_000_000)
        }
        apply(progress: direction > 0 ? 1 : 0)
        if direction < 0 { solar.root.isEnabled = false }
        logRunReadings()
        SessionLog.append(String(format: "probe.%@ end samples=%d", phase, readings.count))
    }

    private func apply(progress p: Double) {
        sky.root.isEnabled = p < 1
        sky.setFieldOfView(Float(60 + (55 - 60) * p))
        let a = ScaleLevel.sky.handoffRig
        let b = ScaleLevel.solar.handoffRig
        solarRig = OrbitRig(
            yaw: a.yaw + (b.yaw - a.yaw) * Float(p),
            pitch: a.pitch + (b.pitch - a.pitch) * Float(p),
            distance: a.distance + (b.distance - a.distance) * Float(p)
        )
        solar.apply(
            julianDay: Ephemeris.julianDay(utc: Date()),
            showsOrbits: true,
            rig: solarRig,
            selected: nil
        )
    }
}

struct TransitionProbeView: View {
    @State private var model = ProbeModel()
    @State private var tickCount = 0

    var body: some View {
        ZStack {
            Color(red: 3 / 255, green: 4 / 255, blue: 10 / 255).ignoresSafeArea()
            if let environment = model.environment {
                RealityView { content in
                    content.camera = .virtual
                    content.environment = environment
                    model.attach(content)
                } update: { _ in }
                .ignoresSafeArea()

                RealityView { content in
                    content.camera = .virtual
                    content.environment = environment
                    model.solar.attach(content)
                    content.add(model.solar.root)
                    model.solar.root.isEnabled = false
                    model.solarAttached = true
                } update: { _ in }
                .ignoresSafeArea()
                .opacity(model.progress)
                .allowsHitTesting(false)
            } else {
                ProgressView().tint(.white)
            }
            VStack {
                Text("probe \(model.phase) p=\(String(format: "%.2f", model.progress))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                Text(rulerLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
            .padding(.top, 60)
            .allowsHitTesting(false)
        }
        .task {
            model.loadAssets()
            for _ in 0..<200 where !model.attached || !model.solarAttached {
                try? await Task.sleep(for: .milliseconds(50))
            }
            try? await Task.sleep(for: .seconds(2))
            await model.runRoundtrips(3)
        }
        .onReceive(Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()) { _ in
            tickCount += 1
            guard model.attached, model.phase != "boot", model.phase != "done" else { return }
            SessionLog.append(String(
                format: "probe.frame p=%.3f ruler=%.4e",
                model.progress, model.rulerMeters
            ))
        }
    }

    private var rulerLabel: String {
        let m = model.rulerMeters
        if m >= 9.4607e15 {
            return String(format: "%.0f 光年", m / 9.4607e15)
        }
        return String(format: "%.2f AU", m / 1.495978707e11)
    }
}