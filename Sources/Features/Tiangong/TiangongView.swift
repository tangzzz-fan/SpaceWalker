import RealityKit
import SwiftUI
import TGReduxKit

struct TiangongView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    @Bindable var session: TiangongSession

    @State private var environment: RealityViewEnvironment?
    @State private var probeLine: String?
    @State private var showsHistory = false
    @State private var dragMode: DragMode = .none
    @State private var lastDrag: CGSize = .zero
    @State private var lastRotation: Double = 0
    @State private var lastFPSLog: TimeInterval = 0
    @State private var dockTicker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private enum DragMode { case none, orbit, module, docking }

    var body: some View {
        ZStack {
            Color(red: 0.012, green: 0.016, blue: 0.038)
                .ignoresSafeArea()

            if let environment {
                reality(environment)
            }

            if !LaunchMode.tiangongLabelsHidden(environment: ProcessInfo.processInfo.environment) {
                labelLayer
            }

            VStack(alignment: .leading, spacing: 0) {
                topBar
                Spacer(minLength: 0)
                if session.dockingActive {
                    dockingCard
                        .padding(.bottom, 10)
                } else if let selected = session.selected {
                    infoCard(selected)
                        .padding(.bottom, 10)
                }
                controlBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .preferredColorScheme(.dark)
        .task {
            environment = SpaceEnvironment.load()
            // 碰撞体与投影要等渲染就绪，立刻自检会全空。
            try? await Task.sleep(for: .seconds(1.2))
            probeLine = session.scene.verifyPicking()
        }
        .onReceive(dockTicker) { _ in
            session.stepClock(delta: 0.1)
            if session.dockingActive {
                session.stepDocking(delta: 0.1)
            }
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastFPSLog >= 2 {
                lastFPSLog = now
                session.logFrameRate(now: now)
            }
        }
        .sheet(isPresented: $showsHistory) {
            TiangongHistorySheet()
        }
    }

    /// 部件名常驻在投影位置上。几何只到「示意」的程度，命名交给标签，
    /// 用户至少能回答「这是哪一段」——062 的降级方案。
    private var labelLayer: some View {
        // TimelineView 自己按 0.1s 刷新，不把锚点写回 @State——
        // 写回状态会让整个 body 重建，RealityView 跟着重算，画面会闪。
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let anchors = session.labelAnchors()
            ZStack {
                ForEach(TiangongModuleID.allCases) { id in
                    if let point = anchors[id] {
                        Text(id.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
                            .position(x: point.x, y: point.y - 24)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func reality(_ environment: RealityViewEnvironment) -> some View {
        RealityView { content in
            content.camera = .virtual
            content.environment = environment
            session.scene.rebuild()
            content.add(session.scene.root)
            session.attach(content)
            session.applyRig()
            session.applyOrbit()
        } update: { _ in
            session.applyRig()
        }
        .coordinateSpace(name: "tiangong")
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { session.viewSize = proxy.size }
                    .onChange(of: proxy.size) { _, size in session.viewSize = size }
            }
        )
        .gesture(orbitGesture)
        .simultaneousGesture(zoomGesture)
        .simultaneousGesture(rotateGesture)
        .simultaneousGesture(selectGesture)
    }

    /// 按下时先判定这次手势归谁：按在已分离的模块上是拖模块，否则转相机。
    /// 判定只做一次，中途不切换——否则拖到一半相机会跟着转。
    private var orbitGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragMode == .none {
                    if session.dockingActive {
                        dragMode = .docking
                    } else if session.beginModuleDrag(at: value.startLocation) {
                        dragMode = .module
                    } else {
                        dragMode = .orbit
                    }
                    lastDrag = .zero
                }
                switch dragMode {
                case .module:
                    session.dragModule(translation: value.translation)
                case .orbit:
                    session.rotate(translation: value.translation)
                case .docking:
                    let delta = CGSize(
                        width: value.translation.width - lastDrag.width,
                        height: value.translation.height - lastDrag.height
                    )
                    session.moveShip(drag: delta, magnification: 1)
                    lastDrag = value.translation
                case .none:
                    break
                }
            }
            .onEnded { _ in
                switch dragMode {
                case .module: session.endModuleDrag()
                case .orbit: session.endDrag()
                case .docking: lastDrag = .zero
                case .none: break
                }
                dragMode = .none
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if session.dockingActive {
                    session.moveShip(drag: .zero, magnification: value.magnification)
                } else {
                    session.magnify(value.magnification)
                }
            }
            .onEnded { _ in
                if !session.dockingActive {
                    session.endMagnify()
                }
            }
    }

    /// 双指旋转只在对接模式下有意义，其余时候吃掉手势会挡住缩放。
    private var rotateGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                guard session.dockingActive else { return }
                let degrees = value.rotation.degrees
                session.rotateShip(degrees: degrees - lastRotation)
                lastRotation = degrees
            }
            .onEnded { _ in
                lastRotation = 0
            }
    }

    private var selectGesture: some Gesture {
        SpatialTapGesture(coordinateSpace: .named("tiangong"))
            .onEnded { value in
                session.pick(at: value.location)
            }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(TiangongHistory.name)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(TiangongHistory.kind)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("1:\(Int(TiangongScale.ratio)) 展示 · 全长 \(formatted(TiangongModel.totalLength)) · 最大直径 \(formatted(TiangongModel.maxDiameter))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(TiangongHistory.facts.prefix(2).map { "\($0.label) \($0.value)" }.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("任务 \(session.mission.phase.ordinal)/3 · \(TiangongMission.summary(session.mission)) · 第 \(session.completedOrbits + 1) 圈")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let probeLine {
                Text("pick · \(probeLine)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func infoCard(_ module: TiangongModuleID) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "shippingbox")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(module.title)
                    .font(.headline)
                Spacer(minLength: 6)
            }
            Text(module.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if TiangongDisassembly.isDismantlable(module) {
                Button(session.separated.contains(module) ? "装回" : "分离") {
                    session.toggleDisassembly(module)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
            }
            Text("点空白处取消选择 · 神舟不参与拆装")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func formatted(_ meters: Float) -> String {
        TiangongFormat.meters(meters)
    }

    private var dockingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "dot.scope")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(session.dockingHeadline ?? "")
                    .font(.headline)
                Spacer(minLength: 6)
                Button(session.controlMode == .coarse ? "粗调" : "精调") {
                    session.toggleControlMode()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            if case .failed = session.dockingOutcome {
                Button("重试") { session.resetDocking() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            if session.mission.phase == .complete {
                Button("重玩整个任务") { session.replayMission() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            Text("拖动平移 · 捏合推进 · 双指旋转调姿态")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("姿态偏差 \(Int(max(abs(session.shipYaw), abs(session.shipPitch))))° / 容差 \(Int(TiangongDocking.angleTolerance))°")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var controlBar: some View {
        HStack(spacing: 18) {
            Button {
                session.resetView()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("重置视角")

            Button {
                store.dispatch(.route(.solarSystem))
            } label: {
                Image(systemName: "circle.hexagongrid")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("太阳系")

            Button {
                store.dispatch(.route(.sky))
            } label: {
                Image(systemName: "sparkles")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("星图")

            Button {
                if session.dockingActive {
                    session.endDocking()
                } else {
                    session.beginDocking()
                }
            } label: {
                Image(systemName: session.dockingActive ? "xmark.circle" : "arrow.up.forward.circle")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(session.dockingActive ? "退出对接" : "对接任务")

            Button {
                session.toggleOrbitPace()
            } label: {
                Image(systemName: session.orbitPace == TiangongOrbitClock.paceSlow ? "tortoise" : "hare")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("切换轨道速度")

            Button {
                showsHistory = true
            } label: {
                Image(systemName: "info.circle")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("史实")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct TiangongHistorySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TiangongHistory.name)
                        .font(.title3.weight(.semibold))
                    Text(TiangongHistory.kind)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("关闭")
            }

            ForEach(TiangongHistory.facts) { fact in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(fact.value)
                        .font(.subheadline)
                }
            }

            Text("史实条目与出处见 docs/research/realitykit-ios26-primary-sources.md 第 15 条。")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .preferredColorScheme(.dark)
    }
}
