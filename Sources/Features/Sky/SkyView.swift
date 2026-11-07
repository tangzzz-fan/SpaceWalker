import RealityKit
import SwiftUI
import TGReduxKit

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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if catalog != nil {
                GeometryReader { _ in
                    reality
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
        .task { await load() }
        .onDisappear { attitude.stop() }
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
                    SessionLog.append("sky.select name=\(hit?.name ?? "none") mag=\(hit?.magnitude ?? 0)")
                }
        )
    }

    private var crosshair: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.55), lineWidth: 1)
                .frame(width: 44, height: 44)
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
            Text("\(catalog?.stars.count ?? 0) 颗恒星 · 赤道坐标 J2000")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(motionActive ? "姿态跟随 · 转动手机环顾" : "拖动旋转（无陀螺仪时的降级）")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
    }

    private func startMotion() {
        guard LaunchMode.skyMotionEnabled(environment: ProcessInfo.processInfo.environment) else { return }
        guard !attitude.isAvailable else { return }
        attitude.start { orientation in
            scene.setAttitude(orientation)
        }
        motionActive = attitude.isAvailable
    }
}
