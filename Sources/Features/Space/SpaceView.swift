import Foundation
import RealityKit
import SwiftUI
import TGReduxKit

struct SpaceView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    let actions: ChromeActionRegistry

    @State private var scene = SolarSystemScene()
    #if DEBUG
    @State private var probe = ProbeRecorder()
    #endif
    @State private var environment: RealityViewEnvironment?
    @State private var rig = OrbitRig()
    @State private var canvasSize: CGSize = .zero
    @State private var showsCredits = false
    @State private var ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    @State private var lastTick = ProcessInfo.processInfo.systemUptime
    @State private var labelPoint: CGPoint?
    @State private var lastProbe: TimeInterval = 0

    private var state: SolarSystemState {
        store.state.space
    }

    private var selectedBody: SolarBody? {
        state.selected.flatMap(SolarSystem.body)
    }

    var body: some View {
        ZStack {
            Color(red: 0.012, green: 0.016, blue: 0.038)
                .ignoresSafeArea()

            if let environment {
                GeometryReader { proxy in
                    reality(environment)
                        .onAppear { canvasSize = proxy.size }
                        .onChange(of: proxy.size) { _, size in canvasSize = size }
                }
            }

            if let selectedBody, let labelPoint {
                Text(selectedBody.name)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .position(x: labelPoint.x, y: labelPoint.y - 34)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                if store.state.chrome.infoCard != nil, let selectedBody {
                    infoCard(selectedBody)
                        .padding(.horizontal, ChromeTokens.edgePadding)
                        .padding(.bottom, ChromeTokens.horizontalPadding)
                        .modifier(ChromeInfoCardBehavior(
                            ratio: store.state.chrome.infoCard?.maxHeightRatio
                                ?? ChromeTokens.infoCardMaxHeightRatio
                        ) { store.dispatch(.space(.select(nil))) })
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadEnvironment()
            applyDebugPreselection()
        }
        .onAppear(perform: registerActions)
        .onChange(of: selectedBody != nil) { _, hasSelection in
            store.dispatch(.chrome(.setMode(hasSelection ? .card : .normal)))
        }
        .onChange(of: Int(state.days)) { _, _ in updateStatus() }
        .onChange(of: state.isPaused) { _, _ in updateStatus() }
        .onAppear(perform: updateStatus)
        .onReceive(ticker) { _ in tick() }
        .sheet(isPresented: $showsCredits) {
            creditsSheet
        }
    }

    private func updateStatus() {
        let phase = state.isPaused ? "已暂停" : "运行中"
        store.dispatch(.chrome(.setStatus("\(phase) · 第 \(Int(state.days)) 天")))
    }

    private func registerActions() {
        let store = self.store
        actions.primary = { id in
            switch id {
            case .spaceOverview:
                rig = OrbitRig()
                store.dispatch(.space(.select(nil)))
            case .spaceFocus:
                rig = OrbitRig()
            default:
                break
            }
        }
        actions.control = { id in
            switch id {
            case .spacePause:
                store.dispatch(.space(.togglePause))
            case .spaceRate:
                let current = store.state.space.rateInRange
                let next = current + 1 > SolarSystemState.rateRange.upperBound
                    ? SolarSystemState.rateRange.lowerBound
                    : current + 1
                store.dispatch(.space(.setRate(next)))
            case .spaceOrbits:
                store.dispatch(.space(.toggleOrbits))
            case .credits, .history:
                showsCredits = true
            default:
                break
            }
        }
    }

    private func reality(_ environment: RealityViewEnvironment) -> some View {
        RealityView { content in
            content.camera = .virtual
            content.environment = environment
            scene.build()
            content.add(scene.root)
            scene.attach(content)
            #if DEBUG
            probe.attach(content)
            #endif
            scene.apply(
                days: store.state.space.days,
                showsOrbits: store.state.space.showsOrbits,
                rig: rig,
                selected: store.state.space.selected
            )
        } update: { _ in
            scene.apply(
                days: store.state.space.days,
                showsOrbits: store.state.space.showsOrbits,
                rig: rig,
                selected: store.state.space.selected
            )
        }
        .coordinateSpace(name: SolarSystemScene.coordinateSpaceName)
        .gesture(orbitGesture)
        .simultaneousGesture(zoomGesture)
        .simultaneousGesture(selectGesture)
    }

    private var orbitGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                rig.rotate(
                    deltaX: Float(value.translation.width - lastDrag.width),
                    deltaY: Float(value.translation.height - lastDrag.height)
                )
                lastDrag = value.translation
            }
            .onEnded { _ in
                lastDrag = .zero
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let current = value.magnification
                rig.dolly(scale: Float(current / max(lastMagnification, 0.001)))
                lastMagnification = current
            }
            .onEnded { _ in
                lastMagnification = 1
            }
    }

    private var selectGesture: some Gesture {
        SpatialTapGesture(coordinateSpace: .named(SolarSystemScene.coordinateSpaceName))
            .onEnded { value in
                let hit = scene.pick(at: value.location)
                store.dispatch(.space(.select(hit)))
                SessionLog.append("space.select id=\(hit?.rawValue ?? "none")")
            }
    }

    @State private var lastDrag: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1

    private func infoCard(_ body: SolarBody) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(body.name)
                    .font(.headline)
                Text(body.latinName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(body.kind == .star ? "恒星" : "行星")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.12), in: Capsule())
                    .padding(.trailing, 24)
            }
            Text("直径 \(formatted(body.diameterKilometers)) km")
                .font(.caption)
                .foregroundStyle(.secondary)
            if body.semiMajorAxisAU > 0 {
                Text(String(format: "距日 %.3f AU · 公转 %.1f 地球日", body.semiMajorAxisAU, body.orbitalPeriodDays))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(body.blurb)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Text("比例为可读性做了非线性压缩，非真实比例")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            Button {
                store.dispatch(.space(.select(nil)))
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
                Text("素材来源")
                    .font(.title3.weight(.semibold))

                creditRow(
                    title: "星空底图",
                    detail: "NASA/Goddard Space Flight Center Scientific Visualization Studio · Deep Star Maps 2020（公有领域）"
                )
                creditRow(
                    title: "恒星数据",
                    detail: "Gaia DR2 · ESA/Gaia/DPAC"
                )
                creditRow(
                    title: "行星参数",
                    detail: "NASA Planetary Fact Sheet · JPL Solar System Dynamics"
                )

                Text("NASA 未参与本项目，也未对其背书。本应用不使用 NASA 标识。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("底图原始为 OpenEXR 线性 HDR，构建期做了 +0.9EV 曝光与轻度饱和调整后转存为 sRGB JPEG。行星为程序化几何，比例经非线性压缩。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .presentationDetents([.medium])
    }

    private func creditRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    @MainActor
    private func applyDebugPreselection() {
        #if DEBUG
        guard store.state.space.selected == nil,
              let raw = ProcessInfo.processInfo.environment["SPACEWALKER_SELECT"],
              let id = BodyID(rawValue: raw)
        else {
            return
        }
        store.dispatch(.space(.select(id)))
        SessionLog.append("space.select.preset \(raw)")
        #endif
    }

    private func loadEnvironment() async {
        guard environment == nil else { return }
        let started = ProcessInfo.processInfo.systemUptime
        environment = SpaceEnvironment.load()
        SessionLog.append(
            String(
                format: "space.environment ready=%d elapsedMs=%.0f",
                environment != nil,
                (ProcessInfo.processInfo.systemUptime - started) * 1000
            )
        )
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let delta = min(max(now - lastTick, 0), 0.2)
        lastTick = now

        if !store.state.space.isPaused {
            store.dispatch(.space(.advance(seconds: delta)))
        }

        if let selected = store.state.space.selected {
            labelPoint = scene.screenPoint(for: selected)
        } else {
            labelPoint = nil
        }

        #if DEBUG
        _ = probe.tick(now: now, anchorPosition: nil)
        #endif

        #if DEBUG
        if LaunchMode.pickProbeEnabled(environment: ProcessInfo.processInfo.environment) {
            runPickProbe(now: now)
        }
        #endif
    }

    #if DEBUG
    private func runPickProbe(now: TimeInterval) {
        guard now - lastProbe >= 2, canvasSize != .zero else { return }
        lastProbe = now
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let hit = scene.pick(at: center)
        SessionLog.append(
            "space.pickProbe center=\(Int(center.x)),\(Int(center.y)) hit=\(hit?.rawValue ?? "none")"
        )
        SessionLog.append("space." + scene.verifyPicking())
    }
    #endif
}
