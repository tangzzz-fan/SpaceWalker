import RealityKit
import SwiftUI
import TGReduxKit
import UIKit

struct SkyView: View {
    @Environment(Store<AppState, AppAction>.self) private var store

    @State private var scene = SkyScene()
    @State private var catalog: StarCatalog?
    @State private var rig = SkyRig()
    @State private var attitude = DeviceAttitude()
    @State private var lastDrag: CGSize = .zero
    @State private var selected: Star?
    @State private var motionActive = false
    @State private var showsCredits = false
    @State private var dwell = DwellSelector()
    @State private var hud = DwellHUD()
    @State private var observer = SkyObserver()
    @State private var alignmentStamp: TimeInterval = 0
    @State private var diagnosticsStamp: TimeInterval = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if catalog != nil {
                GeometryReader { proxy in
                    reality
                        .onAppear { scene.resize(proxy.size) }
                        .onChange(of: proxy.size) { _, size in scene.resize(size) }
                }
            } else {
                ProgressView()
                    .tint(.white)
            }

            crosshair

            VStack(alignment: .leading, spacing: 0) {
                topBar
                Spacer(minLength: 0)
                if let selected {
                    starCard(selected)
                        .padding(.bottom, 10)
                }
                hintBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .preferredColorScheme(.dark)
        .task {
            await load()
            await runPickProbe()
        }
        .onChange(of: observer.stage) { _, _ in
            alignmentStamp = 0
            applyAlignment()
        }
        .onDisappear {
            attitude.stop()
            observer.disable()
        }
        .sheet(isPresented: $showsCredits) { creditsSheet }
    }

    private var reality: some View {
        RealityView { content in
            content.camera = .virtual
            content.environment = .default
            guard let catalog else { return }
            scene.build(catalog: catalog)
            content.add(scene.root)
            scene.attach(content)
            scene.apply(rig: rig)
        } update: { _ in
            scene.apply(rig: rig)
        }
        .coordinateSpace(name: SkyScene.coordinateSpaceName)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard !motionActive else { return }
                    rig.drag(
                        deltaX: Float(value.translation.width - lastDrag.width),
                        deltaY: Float(value.translation.height - lastDrag.height)
                    )
                    lastDrag = value.translation
                }
                .onEnded { _ in lastDrag = .zero }
        )
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .named(SkyScene.coordinateSpaceName))
                .onEnded { value in
                    let hit = scene.pick(at: value.location)
                    selected = hit
                    dwell.reset()
                    hud.show(0)
                    SessionLog.append("sky.select name=\(hit?.name ?? "none") mag=\(hit?.magnitude ?? 0)")
                }
        )
    }

    private var crosshair: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.55), lineWidth: 1)
                .frame(width: 44, height: 44)
            DwellRing(hud: hud)
            Circle()
                .fill(.white.opacity(0.75))
                .frame(width: 3, height: 3)
        }
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("星图")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(skySubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(motionActive ? "姿态跟随 · 转动手机环顾" : "拖动旋转（无陀螺仪时的降级）")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(observer.statusText)
                .font(.caption2)
                .foregroundStyle(observer.isOn ? .primary : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var skySubtitle: String {
        guard observer.stage == .ready,
              let latitude = observer.latitude,
              let longitude = observer.longitude,
              let sidereal = observer.currentSiderealDegrees()
        else {
            return "\(catalog?.stars.count ?? 0) 颗恒星 · 赤道坐标 J2000"
        }
        return String(format: "%.1f°N %.1f°E · 恒星时 %.1f°", latitude, longitude, sidereal)
    }

    private var hintBar: some View {
        HStack(spacing: 12) {
            if !motionActive {
                Button {
                    rig = SkyRig()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("重置视角")
            }

            Spacer()

            Button {
                toggleAlignment()
            } label: {
                Label(observer.isOn ? "今夜" : "对齐今夜", systemImage: observer.isOn ? "location.fill" : "location")
                    .font(.caption)
            }
            .accessibilityLabel("对齐今夜此刻的真实天空")

            Button {
                store.dispatch(.route(.solarSystem))
            } label: {
                Label("太阳系", systemImage: "sun.max")
                    .font(.caption)
            }

            Button {
                showsCredits = true
            } label: {
                Image(systemName: "info.circle")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("素材来源")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func starCard(_ star: Star) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(star.name.isEmpty ? "未命名恒星" : star.name)
                    .font(.headline)
                Spacer()
                Text(star.constellation.isEmpty ? "—" : star.constellation)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            Text(String(format: "视星等 %.2f · 赤经 %.2fh · 赤纬 %.1f°", star.magnitude, star.rightAscensionHours, star.declinationDegrees))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "色指数 %.2f（越小越偏蓝）", star.colorIndex))
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let horizontal = horizontal(for: star) {
                Text(String(format: "高度 %.1f° · 方位 %.1f°（此刻）", horizontal.altitude, horizontal.azimuth))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            Button {
                selected = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }

    private var creditsSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("数据来源")
                    .font(.title3.weight(.semibold))
                Text("恒星数据：HYG Database v4.1（CC BY-SA 4.0），由 Hipparcos、Yale BSC、Glise 等编目汇编。本次仅取视星等 ≤ 4.5 或有专名的 1102 颗。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("坐标系：J2000 赤道坐标，尚未做时间与地理位置的周日旋转对齐。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("本页数据以 CC BY-SA 4.0 提供，衍生子集同样适用该许可。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .presentationDetents([.medium])
    }

    @MainActor
    private func load() async {
        if catalog == nil {
            let started = ProcessInfo.processInfo.systemUptime
            let loaded = StarCatalog.loadFromBundle()
            catalog = loaded
            SessionLog.append(
                String(
                    format: "sky.catalog stars=%d elapsedMs=%.0f",
                    loaded?.stars.count ?? 0,
                    (ProcessInfo.processInfo.systemUptime - started) * 1000
                )
            )
        }
        startMotion()
        if LaunchMode.autoAlignEnabled(environment: ProcessInfo.processInfo.environment), !observer.isOn {
            observer.enable()
        }
    }

    private func startMotion() {
        guard LaunchMode.skyMotionEnabled(environment: ProcessInfo.processInfo.environment) else { return }
        guard !attitude.isAvailable else { return }
        attitude.start { orientation in
            scene.setAttitude(orientation)
            observer.calibrate(sceneAzimuth: Astronomy.sceneAzimuth(scene.deviceForwardWorld))
            applyAlignment()
            stepDwell()
        }
        motionActive = attitude.isAvailable
    }

    private func toggleAlignment() {
        if observer.isOn {
            observer.disable()
            scene.setField(orientation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))
            alignmentStamp = 0
            SessionLog.append("sky.align off")
        } else {
            observer.enable()
            alignmentStamp = 0
        }
    }

    private func applyAlignment() {
        guard observer.isOn else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - alignmentStamp > 1 else { return }
        alignmentStamp = now
        guard let orientation = observer.fieldOrientation() else { return }
        scene.setField(orientation: orientation)
    }

    private func horizontal(for star: Star) -> Astronomy.Horizontal? {
        guard observer.stage == .ready,
              let latitude = observer.latitude,
              let sidereal = observer.currentSiderealDegrees()
        else {
            return nil
        }
        return Astronomy.horizontal(
            rightAscensionHours: star.rightAscensionHours,
            declinationDegrees: star.declinationDegrees,
            siderealDegrees: sidereal,
            latitude: latitude
        )
    }

    private func stepDwell() {
        guard scene.isReady else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let candidate = scene.pickAtCenter()
        if candidate == nil, now - diagnosticsStamp > 1.5,
           LaunchMode.pickProbeEnabled(environment: ProcessInfo.processInfo.environment) {
            diagnosticsStamp = now
            SessionLog.append(scene.pickDiagnostics())
        }
        let hit = dwell.update(candidate: candidate, at: now)
        hud.show(dwell.progress)
        guard let hit else { return }
        selected = hit
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        SessionLog.append(String(format: "sky.dwell name=%@ mag=%.2f", hit.name, hit.magnitude))
    }

    private func runPickProbe() async {
        guard LaunchMode.pickProbeEnabled(environment: ProcessInfo.processInfo.environment) else { return }
        for _ in 0..<60 {
            let alignmentSettled = !observer.isOn
                || observer.stage == .ready
                || observer.stage == .denied
                || observer.stage == .unavailable
            if scene.isReady, alignmentSettled { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard scene.isReady else {
            SessionLog.append("sky.pickProbe skipped=not-ready")
            return
        }
        SessionLog.append(scene.pickRoundtrip())
    }
}

private struct DwellRing: View {
    var hud: DwellHUD

    var body: some View {
        Circle()
            .trim(from: 0, to: hud.progress)
            .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: 41, height: 41)
            .opacity(hud.progress > 0.01 ? 0.95 : 0)
    }
}
