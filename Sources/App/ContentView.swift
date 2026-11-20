import RealityKit
import SwiftUI
import TGReduxKit

struct ContentView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var skySession = SkySession()
    @State private var tiangongSession = TiangongSession()
    @State private var solarScene = SolarSystemScene()
    @State private var earthScene = EarthOrbitScene()
    @State private var actions = ChromeActionRegistry()
    @State private var engine = ScaleTransitionEngine()
    @State private var ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    private var isLandscape: Bool { verticalSizeClass == .compact }
    private var route: ScaleLevel { store.state.route }

    var body: some View {
        ZStack {
            ChromeTokens.spaceBackground.ignoresSafeArea()

            layer(.sky) {
                SkyView(actions: actions, session: skySession, engine: engine)
            }
            layer(.solar) {
                SpaceView(actions: actions, scene: solarScene, engine: engine)
            }
            layer(.earthOrbit) {
                EarthOrbitView(actions: actions, scene: earthScene, engine: engine)
            }
            layer(.tiangong) {
                TiangongView(actions: actions, session: tiangongSession, engine: engine)
            }

            if isLandscape {
                VStack {
                    Spacer(minLength: 0)
                    ScaleLadderView(
                        nodes: store.state.chrome.ladder,
                        current: route,
                        isLandscape: true,
                        onSelect: navigate,
                        onOverview: { store.dispatch(.overview) }
                    )
                    .padding(.horizontal, ChromeTokens.edgePadding)
                    .padding(.bottom, ChromeTokens.horizontalPadding)
                }
                .allowsHitTesting(!engine.isTransitioning)
            } else {
                HStack {
                    Spacer(minLength: 0)
                    VStack {
                        Spacer(minLength: 0)
                        ScaleLadderView(
                            nodes: store.state.chrome.ladder,
                            current: route,
                            isLandscape: false,
                            onSelect: navigate,
                            onOverview: { store.dispatch(.overview) }
                        )
                        Spacer(minLength: 0)
                    }
                    .frame(width: ChromeTokens.ladderNodeWidth)
                    .padding(.trailing, ChromeTokens.ladderEdgeInset)
                    .offset(y: ChromeTokens.sectionSpacing)
                }
                .allowsHitTesting(!engine.isTransitioning)
            }

            VStack {
                Spacer(minLength: 0)
                AttitudeRestoreToast(token: store.state.attitudeRestoreNoticeToken)
                    .padding(.bottom, ChromeTokens.horizontalPadding)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                ChromeStatusBar(status: store.state.chrome.statusLine, actions: actions)
                ScaleRulerBar(
                    level: route,
                    readingMeters: engine.readingMeters,
                    isLandscape: isLandscape
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChromeBottomBar(actions: actions)
        }
        .sheet(isPresented: diagnosticsBinding) {
            ChromeDiagnosticsSheet()
        }
        .preferredColorScheme(store.state.chrome.theme == .dark ? .dark : .light)
        .onAppear(perform: bindEngine)
        .onReceive(ticker) { _ in
            engine.solarJulianDay = store.state.space.julianDay
            engine.solarShowsOrbits = store.state.space.showsOrbits
            engine.solarSelected = store.state.space.selected
            engine.solarTrueScale = store.state.space.narrative.isPlaying
            engine.tick(now: ProcessInfo.processInfo.systemUptime)
        }
        .onChange(of: store.state.transition) { _, request in
            guard let request else { return }
            engine.begin(request)
        }
        .onChange(of: store.state.overviewToken) { _, token in
            guard token > 0 else { return }
            resetOverview(for: route)
        }
    }

    @ViewBuilder
    private func layer<Content: View>(_ level: ScaleLevel, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(layerVisible(level) ? engine.opacity(for: level) : Self.hiddenLayerOpacity)
            .allowsHitTesting(engine.isInteractive(level, route: route))
    }

    /// opacity=0 会让 RealityKit 停渲染并回收 GPU 资源，转场渐入时首帧重建
    /// 阻塞主线程 0.8–0.9s（尺子插值只剩首尾两点）。保留 0.2% 透明度让四层
    /// 持续渲染，深色背景上不可察觉，GPU 资源常驻。
    private static let hiddenLayerOpacity: Double = 0.002

    private func layerVisible(_ level: ScaleLevel) -> Bool {
        level == route || level == engine.outgoing
    }

    private func navigate(to target: ScaleLevel) {
        store.dispatch(.route(target))
    }

    private func bindEngine() {
        engine.skySession = skySession
        engine.solarScene = solarScene
        engine.earthScene = earthScene
        engine.tiangongSession = tiangongSession
        engine.readingMeters = route.representativeMeters
        if route == .sky {
            skySession.setFollowsAttitude(true)
        } else {
            skySession.setFollowsAttitude(false)
        }
    }

    private func resetOverview(for level: ScaleLevel) {
        SessionLog.append("scale.overview level=\(level)")
        switch level {
        case .sky:
            skySession.resetZoom()
            skySession.resetOrientation()
            skySession.setFollowsAttitude(true)
        case .solar:
            engine.solarRig = OrbitRig()
            store.dispatch(.space(.select(nil)))
            store.dispatch(.space(.enterOverview))
        case .earthOrbit:
            engine.earthStop = .overview
            engine.earthRig = EarthOrbitCameraStop.overview.rig
        case .tiangong:
            tiangongSession.resetView()
        }
    }

    private var diagnosticsBinding: Binding<Bool> {
        Binding(
            get: { store.state.chrome.diagnosticsVisible },
            set: { presented in
                guard !presented, store.state.chrome.diagnosticsVisible else { return }
                store.dispatch(.chrome(.toggleDiagnostics))
            }
        )
    }
}