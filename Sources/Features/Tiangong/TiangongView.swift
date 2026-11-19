import RealityKit
import SwiftUI
import TGReduxKit

struct TiangongView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    let actions: ChromeActionRegistry
    @Bindable var session: TiangongSession

    @State private var environment: RealityViewEnvironment?
    @State private var showsHistory = false
    @State private var dragMode: DragMode = .none
    @State private var lastDrag: CGSize = .zero
    @State private var lastRotation: Double = 0
    @State private var lastFPSLog: TimeInterval = 0
    @State private var reentryHintToken = 0
    @State private var dockTicker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private enum DragMode { case none, orbit, module, docking }

    var body: some View {
        ZStack {
            ChromeTokens.spaceBackground
                .ignoresSafeArea()

            if let environment {
                reality(environment)
            }

            if !session.drawingMode,
               !session.reentryActive,
               !LaunchMode.tiangongLabelsHidden(environment: ProcessInfo.processInfo.environment) {
                labelLayer
            }

            if session.drawingMode, !session.reentryActive {
                dimensionLayer
                viewPicker
            }

            if session.reentryActive {
                reentryOverlay
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    if session.dockingActive {
                        dockingCard
                            .padding(.bottom, ChromeTokens.horizontalPadding)
                    } else if store.state.chrome.infoCard != nil, let selected = session.selected {
                        infoCard(selected)
                            .padding(.bottom, ChromeTokens.horizontalPadding)
                            .modifier(ChromeInfoCardBehavior(
                                ratio: store.state.chrome.infoCard?.maxHeightRatio
                                    ?? ChromeTokens.infoCardMaxHeightRatio
                            ) { dismissSelection() })
                    }
                    if session.cutawayMode {
                        cutawayCard
                            .padding(.bottom, ChromeTokens.horizontalPadding)
                    }
                }
                .padding(.horizontal, ChromeTokens.edgePadding)
                .padding(.bottom, ChromeTokens.horizontalPadding)
            }
        }
        .onAppear(perform: registerActions)
        .onAppear(perform: syncLaunchSelection)
        .onChange(of: session.reentryPhase) { _, _ in syncMode() }
        .onChange(of: session.drawingMode) { _, _ in syncMode() }
        .onChange(of: session.cutawayMode) { _, _ in syncMode() }
        .onChange(of: session.dockingActive) { _, _ in syncMode() }
        .onChange(of: session.controlMode) { _, mode in
            store.dispatch(.chrome(.setDockingFine(mode == .fine)))
        }
        .onChange(of: session.canStartReentry) { _, unlocked in
            store.dispatch(.chrome(.setReentryUnlocked(unlocked)))
        }
        .onChange(of: session.separated) { _, separated in
            store.dispatch(.chrome(.setSeparation(Set(separated.map(\.rawValue)))))
        }
        .onChange(of: session.selected) { _, selected in
            store.dispatch(.chrome(.select(selected.map(ChromeSelection.module))))
            syncMode()
        }
        .onChange(of: showsHistory) { _, open in
            if open {
                session.markMilestonesRead()
            }
            syncMode()
        }
        .task {
            environment = SpaceEnvironment.load()
            if LaunchMode.tiangongDrawing(environment: ProcessInfo.processInfo.environment),
               !session.drawingMode {
                session.toggleDrawingMode()
            }
            if LaunchMode.tiangongCutaway(environment: ProcessInfo.processInfo.environment),
               !session.cutawayMode {
                session.toggleCutawayMode()
            }
            if LaunchMode.tiangongHistorySheet(environment: ProcessInfo.processInfo.environment) {
                showsHistory = true
            }
            if let seconds = LaunchMode.tiangongReentry(environment: ProcessInfo.processInfo.environment) {
                session.startReentry(ignoringLock: true)
                session.seekReentry(to: seconds)
            }
            // 碰撞体与投影要等渲染就绪，立刻自检会全空。
            try? await Task.sleep(for: .seconds(1.2))
            SessionLog.append("tiangong.pick " + session.scene.verifyPicking())
        }
        .onReceive(dockTicker) { _ in
            session.sunJulianDay = store.state.space.julianDay
            session.stepClock(delta: 0.1)
            session.stepReentry(delta: 0.1)
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
            TiangongHistorySheet {
                showsHistory = false
                store.dispatch(.ascend)
            }
        }
    }

    /// 部件名常驻在投影位置上。几何只到「示意」的程度，命名交给标签，
    /// 用户至少能回答「这是哪一段」——062 的降级方案。
    private var labelLayer: some View {
        let labels = store.state.chrome.visibleLabels
        return TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let anchors = session.labelAnchors()
            let interiorAnchors = session.scene.interiorAnchors()
            let placed = placedLabels(labels, modules: anchors, interior: interiorAnchors)
            ZStack {
                ForEach(placed, id: \.label.id) { item in
                    Path { path in
                        path.move(to: item.anchor)
                        path.addLine(to: CGPoint(x: item.position.x, y: item.position.y + 12))
                    }
                    .stroke(ChromeTokens.strongHairline, lineWidth: 1)
                    Text(item.label.title)
                        .font(.system(size: ChromeTokens.captionSize, weight: .medium))
                        .foregroundStyle(ChromeTokens.primaryText)
                        .padding(.horizontal, ChromeTokens.horizontalPadding)
                        .padding(.vertical, ChromeTokens.tightPadding)
                        .background(ChromeTokens.surface1.opacity(0.86), in: Capsule())
                        .overlay(Capsule().stroke(ChromeTokens.hairline, lineWidth: 1))
                        .position(item.position)
                        .accessibilityLabel(item.label.title)
                }
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .contain)
        }
    }

    private struct PlacedLabel {
        let label: ChromeLabel
        let anchor: CGPoint
        let position: CGPoint
    }

    /// 三处内景锚点相距只有几十 pt，等高上移会叠字。
    /// 按锚点 y 排序后强制胶囊中心至少间隔 26pt（11pt 字 + 上下 padding ≈ 22pt）。
    private func placedLabels(
        _ labels: [ChromeLabel],
        modules: [TiangongModuleID: CGPoint],
        interior: [String: CGPoint]
    ) -> [PlacedLabel] {
        let resolved: [PlacedLabel] = labels.compactMap { label in
            guard let point = labelPoint(label.id, modules: modules, interior: interior) else { return nil }
            return PlacedLabel(label: label, anchor: point, position: CGPoint(x: point.x, y: point.y - 30))
        }
        var sorted = resolved.sorted { $0.position.y < $1.position.y }
        for index in 1..<max(sorted.count, 1) where index < sorted.count {
            let minY = sorted[index - 1].position.y + 26
            if sorted[index].position.y < minY {
                sorted[index] = PlacedLabel(
                    label: sorted[index].label,
                    anchor: sorted[index].anchor,
                    position: CGPoint(x: sorted[index].position.x, y: minY)
                )
            }
        }
        return sorted
    }

    private func labelPoint(
        _ id: String,
        modules: [TiangongModuleID: CGPoint],
        interior: [String: CGPoint]
    ) -> CGPoint? {
        if id.hasPrefix("interior-") {
            return interior[id]
        }
        return TiangongModuleID(rawValue: id).flatMap { modules[$0] }
    }

    private var dimensionLayer: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            ZStack {
                ForEach(TiangongDimensions.all) { dimension in
                    if let start = session.scene.project(dimension.from),
                       let end = session.scene.project(dimension.to) {
                        Path { path in
                            path.move(to: start)
                            path.addLine(to: end)
                        }
                        .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))

                        Text(dimension.title)
                            .font(.system(size: ChromeTokens.captionSize, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.92))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
                            .position(
                                x: clamped(
                                    (start.x + end.x) / 2 + dimension.labelOffset.width,
                                    in: session.viewSize.width
                                ),
                                y: (start.y + end.y) / 2 + dimension.labelOffset.height
                            )
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// 标注不许被屏幕切掉：左右各留 78pt。
    private func clamped(_ value: CGFloat, in width: CGFloat) -> CGFloat {
        guard width > 0 else { return value }
        return min(max(value, 78), width - 78)
    }

    private var viewPicker: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    ForEach(TiangongRig.Preset.allCases, id: \.self) { preset in
                        Button(preset.title) {
                            session.applyView(preset)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
                .padding(ChromeTokens.compactPadding)
                .background(ChromeTokens.surface1, in: Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, ChromeTokens.edgePadding)
        .padding(.top, 168)
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

    private func syncLaunchSelection() {
        store.dispatch(.chrome(.setSeparation(Set(session.separated.map(\.rawValue)))))
        store.dispatch(.chrome(.setReentryUnlocked(session.canStartReentry)))
        store.dispatch(.chrome(.setDockingFine(session.controlMode == .fine)))
        if let selected = session.selected {
            store.dispatch(.chrome(.select(.module(selected))))
            store.dispatch(.chrome(.setMode(.card)))
        }
    }

    /// PRD-UI:232：锁定态点「再入」给 11pt 提示（与状态条 detail 同源），3 秒回落。
    private func showReentryLockHint() {
        SessionLog.append("tiangong.reentry locked=1")
        store.dispatch(.chrome(.setStatus(ChromeState.reentryLockHint)))
        reentryHintToken += 1
        let token = reentryHintToken
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard token == reentryHintToken else { return }
            syncMode()
        }
    }

    private func dismissSelection() {
        session.selected = nil
        store.dispatch(.chrome(.dismissCard))
    }

    private func registerActions() {
        let store = self.store
        actions.primary = { id in
            switch id {
            case .tiangongDisassemble:
                session.selected = .lab
                if !session.separated.contains(.lab) {
                    session.toggleDisassembly(.lab)
                }
                store.dispatch(.chrome(.select(.module(.lab))))
                store.dispatch(.chrome(.setMode(.card)))
            case .tiangongToggleSeparation:
                guard let module = session.selected else { return }
                session.toggleDisassembly(module)
            case .tiangongApproach:
                session.moveShip(drag: .zero, magnification: 0.95)
            case .tiangongExitCutaway:
                session.toggleCutawayMode()
            case .tiangongExitDrawing:
                session.toggleDrawingMode()
            case .tiangongReentryControl:
                session.skipReentry()
            case .tiangongDismiss:
                showsHistory = false
                session.closeReentry()
            default:
                break
            }
        }
        actions.control = { id in
            switch id {
            case .tiangongCutaway:
                session.toggleCutawayMode()
            case .tiangongDrawing:
                session.toggleDrawingMode()
            case .tiangongReentry:
                if session.canStartReentry {
                    session.startReentry()
                } else {
                    showReentryLockHint()
                }
            case .tiangongResetView:
                session.resetView()
            case .tiangongFrontView:
                session.applyView(.front)
            case .tiangongSideView:
                session.applyView(.side)
            case .tiangongTopView:
                session.applyView(.top)
            case .tiangongCoarse:
                session.setControlMode(.coarse)
            case .tiangongFine:
                session.setControlMode(.fine)
            case .tiangongHistory, .tiangongCredits, .history, .credits:
                showsHistory = true
            default:
                break
            }
        }
    }

    private func syncMode() {
        let store = self.store
        let mode: ChromeMode
        if session.reentryActive {
            mode = .reentry
        } else if session.drawingMode {
            mode = .drawing
        } else if session.cutawayMode {
            mode = .cutaway
        } else if session.dockingActive {
            mode = .docking
        } else if showsHistory {
            mode = .history
        } else if session.selected != nil {
            mode = .card
        } else {
            mode = .normal
        }
        store.dispatch(.chrome(.setMode(mode)))
    }

    private func infoCard(_ module: TiangongModuleID) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "shippingbox")
                    .font(.system(size: ChromeTokens.captionSize))
                    .foregroundStyle(ChromeTokens.secondaryText)
                Text(module.title)
                    .font(.system(size: ChromeTokens.primarySize, weight: .semibold))
                Spacer(minLength: 6)
            }
            Text(module.detail)
                .font(.system(size: ChromeTokens.captionSize))
                .foregroundStyle(ChromeTokens.secondaryText)
            if TiangongDisassembly.isDismantlable(module) {
                Button(session.separated.contains(module) ? "装回" : "分离") {
                    session.toggleDisassembly(module)
                }
                .buttonStyle(.bordered)
                .tint(ChromeTokens.accent)
                .controlSize(.small)
                .padding(.top, 2)
            }
            Text("点空白处取消选择 · 神舟不参与拆装")
                .font(.system(size: ChromeTokens.captionSize))
                .foregroundStyle(ChromeTokens.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ChromeTokens.cardPadding)
        .background(ChromeTokens.surface1, in: RoundedRectangle(cornerRadius: ChromeTokens.edgePadding))
    }

    private func formatted(_ meters: Float) -> String {
        TiangongFormat.meters(meters)
    }

    private var dockingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "dot.scope")
                    .font(.system(size: ChromeTokens.captionSize))
                    .foregroundStyle(ChromeTokens.secondaryText)
                Text(session.dockingHeadline ?? "")
                    .font(.system(size: ChromeTokens.primarySize, weight: .semibold))
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
                if session.canStartReentry {
                    Button("最后一圈") { session.startReentry() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else {
                    Text("打开一次史实面板，解锁「最后一圈」。")
                        .font(.system(size: ChromeTokens.captionSize))
                        .foregroundStyle(ChromeTokens.tertiaryText)
                }
            }
            Text("拖动平移 · 捏合推进 · 双指旋转调姿态")
                .font(.system(size: ChromeTokens.captionSize))
                .foregroundStyle(ChromeTokens.secondaryText)
            Text("姿态偏差 \(Int(max(abs(session.shipYaw), abs(session.shipPitch))))° / 容差 \(Int(TiangongDocking.angleTolerance))°")
                .font(.system(size: ChromeTokens.captionSize))
                .foregroundStyle(ChromeTokens.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ChromeTokens.cardPadding)
        .background(ChromeTokens.surface1, in: RoundedRectangle(cornerRadius: ChromeTokens.edgePadding))
    }

    private var cutawayCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("剖面")
                .font(.system(size: ChromeTokens.captionSize, weight: .semibold))
                .foregroundStyle(ChromeTokens.secondaryText)
            Text("睡眠区 · 健身区 · 设备机柜 · Ø0.8 m 转移通道")
                .font(.system(size: ChromeTokens.captionSize))
                .foregroundStyle(ChromeTokens.secondaryText)
            Text("剖开的是密封舱外壳；内部为示意，不按真实尺寸还原。")
                .font(.system(size: ChromeTokens.captionSize))
                .foregroundStyle(ChromeTokens.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ChromeTokens.cardPadding)
        .background(ChromeTokens.surface1, in: RoundedRectangle(cornerRadius: ChromeTokens.edgePadding))
    }

    private var reentryOverlay: some View {
        ZStack {
            if session.reentryPhase == .card {
                reentryCard
            } else {
                VStack {
                    Spacer()
                    Text(TiangongReentry.caption(session.reentryPhase) ?? "")
                        .font(.system(size: ChromeTokens.labelSize, weight: .medium))
                    .padding(.horizontal, ChromeTokens.edgePadding)
                    .padding(.vertical, ChromeTokens.horizontalPadding)
                    .background(ChromeTokens.surface1, in: Capsule())
                    .padding(.bottom, 60)
                }
            }
        }
    }

    /// 收束卡。文案全部来自 `TiangongHistory.closing`，与史实面板同源。
    private var reentryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最后一圈")
                .font(.system(size: ChromeTokens.captionSize, weight: .semibold))
                .foregroundStyle(ChromeTokens.secondaryText)
            if let closing = TiangongHistory.closing {
                Text(closing.headline)
                    .font(.system(size: ChromeTokens.titleSize, weight: .semibold))
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(closing.date)
                        .font(.system(.title3, design: .monospaced))
                    Text(closing.place)
                        .font(.system(size: ChromeTokens.bodySize))
                        .foregroundStyle(ChromeTokens.secondaryText)
                }
                Text(closing.body)
                    .font(.system(size: ChromeTokens.bodySize))
                    .foregroundStyle(ChromeTokens.secondaryText)
            }
            HStack(spacing: 10) {
                Button("再看一次") { session.replayReentry() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("关闭") { session.closeReentry() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.top, 2)
            Text("史实条目与出处见 docs/research/realitykit-ios26-primary-sources.md 第 15 条。")
                .font(.system(size: ChromeTokens.captionSize))
                .foregroundStyle(ChromeTokens.tertiaryText)
        }
        .padding(ChromeTokens.edgePadding)
        .frame(maxWidth: 360, alignment: .leading)
        .background(ChromeTokens.surface1, in: RoundedRectangle(cornerRadius: ChromeTokens.radiusPanel))
        .padding(ChromeTokens.sectionSpacing)
    }

}

struct TiangongHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    /// 095：回到上层（地月系）的入口。由持有 store 的视图注入，面板自身不碰路由。
    var onReturnToOrbit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TiangongHistory.name)
                        .font(.system(size: ChromeTokens.titleSize, weight: .semibold))
                    Text(TiangongHistory.kind)
                        .font(.system(size: ChromeTokens.labelSize))
                        .foregroundStyle(ChromeTokens.secondaryText)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ChromeTokens.secondaryText)
                }
                .accessibilityLabel("关闭")
            }

            ForEach(TiangongHistory.facts) { fact in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.label)
                        .font(.system(size: ChromeTokens.captionSize))
                        .foregroundStyle(ChromeTokens.secondaryText)
                    Text(fact.value)
                        .font(.system(size: ChromeTokens.bodySize))
                }
            }

            if !TiangongHistory.milestones.isEmpty {
                Divider()
                    .padding(.vertical, 2)
                Text("任务里程碑")
                    .font(.system(size: ChromeTokens.captionSize, weight: .semibold))
                    .foregroundStyle(ChromeTokens.secondaryText)
                ForEach(TiangongHistory.milestones) { milestone in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(milestone.date)
                                .font(.system(size: ChromeTokens.labelSize, design: .monospaced))
                                .foregroundStyle(ChromeTokens.secondaryText)
                            Text(milestone.title)
                                .font(.system(size: ChromeTokens.bodySize, weight: .medium))
                        }
                        Text(milestone.detail)
                            .font(.system(size: ChromeTokens.labelSize))
                        Text(milestone.source)
                            .font(.system(size: ChromeTokens.captionSize))
                            .foregroundStyle(ChromeTokens.tertiaryText)
                    }
                    .padding(.vertical, 2)
                }
            }

            Text("史实条目与出处见 docs/research/realitykit-ios26-primary-sources.md 第 15 条。")
                .font(.system(size: ChromeTokens.captionSize))
                .foregroundStyle(ChromeTokens.tertiaryText)

            if let onReturnToOrbit {
                Button {
                    onReturnToOrbit()
                } label: {
                    Label("回到轨道", systemImage: "arrow.up.circle")
                        .font(.system(size: ChromeTokens.bodySize, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: ChromeTokens.minTouchHeight)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ChromeTokens.accent)
                .accessibilityLabel("回到轨道")
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ChromeTokens.edgePadding)
    }
}
