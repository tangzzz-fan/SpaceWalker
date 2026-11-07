import RealityKit
import SwiftUI
import TGReduxKit
import UIKit

struct SkyView: View {
    @Environment(Store<AppState, AppAction>.self) var store
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @Bindable var session: SkySession

    var scene: SkyScene { session.scene }
    @State var showsCredits = false
    @State var fengshenFocus: AsterismFocus?
    @State var showsFinder = false
    @State var hud = DwellHUD()
    @State var perfSummary: ProbeSummary?
    @State var diagnosticsStamp: TimeInterval = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if session.catalog != nil {
                GeometryReader { proxy in
                    reality
                        .onAppear {
                            session.resize(proxy.size)
                            syncInterfaceOrientation()
                            logLayout(proxy.size)
                        }
                        .onChange(of: proxy.size) { _, size in
                            session.resize(size)
                            syncInterfaceOrientation()
                            logLayout(size)
                        }
                }
            } else {
                ProgressView()
                    .tint(.white)
            }

            crosshair

            if isLandscape {
                landscapeOverlay
            } else {
                portraitOverlay
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await load()
            await runPickProbe()
        }
        .onChange(of: session.showsConstellations) { _, visible in
            scene.setConstellationsVisible(visible)
        }
        .onChange(of: session.showsAsterisms) { _, visible in
            scene.setAsterismsVisible(visible)
        }
        .onChange(of: session.showsOutlines) { _, visible in
            scene.setSilhouettesVisible(visible)
        }
        .onChange(of: session.showsPatterns) { _, visible in
            scene.setPatternsVisible(visible)
            if !visible {
                session.identifiedPattern = nil
            }
        }
        .onChange(of: session.selectedGroup) { _, group in
            scene.highlightAsterism(group?.asterismID)
        }
        .onChange(of: session.observer.stage) { _, _ in
            refreshField()
            refreshTonight()
        }
        .onDisappear {
            session.pause()
            session.observer.disable()
        }
        .sheet(isPresented: $showsCredits) { creditsSheet }
        .sheet(item: $session.infoRegion) { region in
            ConstellationInfoView(region: region, stars: session.catalog?.stars ?? []) { star in
                startGuide(to: star)
            }
        }
        .sheet(item: $fengshenFocus) { target in
            FengshenBoardView(focusAsterism: target.id) { asterism in
                fengshenFocus = nil
                if let group = SkyGroupIndex.group(forAsterism: asterism, in: session.groups) {
                    focus(group: group)
                }
            }
        }
        .sheet(isPresented: $showsFinder) {
            StarFinderView(
                stars: session.catalog?.stars ?? [],
                initialQuery: LaunchMode.finderQuery(environment: ProcessInfo.processInfo.environment),
                tonight: session.tonight,
                referenceDate: session.observer.shiftedNow(),
                initialTour: LaunchMode.tourPreviewEnabled(environment: ProcessInfo.processInfo.environment),
                initialFengshen: LaunchMode.fengshenTarget(environment: ProcessInfo.processInfo.environment),
                onPick: { star in startGuide(to: star) },
                onPickGroup: { group in focus(group: group) }
            )
        }
    }

    /// 画布随界面方向旋转，设备姿态不转——两者差多少，星空就补多少。
    func syncInterfaceOrientation() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else { return }
        session.setInterfaceOrientation(windowScene.interfaceOrientation)
    }

    var reality: some View {
        RealityView { content in
            content.environment = .default
            guard let catalog = session.catalog else { return }
            scene.build(catalog: catalog)
            content.add(scene.root)
            scene.attach(content)
            if LaunchMode.perfLogEnabled(environment: ProcessInfo.processInfo.environment) {
                session.perf.attach(content)
            }
            session.applyRig()
        } update: { _ in
            session.applyRig()
        }
        .coordinateSpace(name: SkyScene.coordinateSpaceName)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    session.drag(to: value.translation)
                }
                .onEnded { _ in
                    session.endDrag()
                }
        )
        // 双指捏合改视场角。人放在星空上叫「看全」，不是在缩放图片：
        // 人马座 35° 装不进 36° 的竖屏视场，只能连视场一起放大。
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    session.magnify(value.magnification)
                }
                .onEnded { _ in
                    session.endMagnify()
                }
        )
        // 双击回到默认视场。缩放没有「复位」就等于没有退出键，
        // 放到 95° 之后很难再捏回 60°。
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                session.resetZoom()
            }
        )
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .named(SkyScene.coordinateSpaceName))
                .onEnded { value in
                    let hit = scene.pick(at: value.location)
                    session.selected = hit
                    session.selectedGroup = nil
                    session.attention.resetStar()
                    hud.show(0)
                    SessionLog.append("sky.select name=\(hit?.name ?? "none") mag=\(hit?.magnitude ?? 0)")
                }
        )
    }

}

struct DwellRing: View {
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

struct AsterismFocus: Identifiable, Equatable {
    var id: String
}
