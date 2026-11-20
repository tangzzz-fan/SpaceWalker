import Foundation
import RealityKit
import SwiftUI
import TGReduxKit

struct EarthOrbitView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    let actions: ChromeActionRegistry

    let scene: EarthOrbitScene
    let engine: ScaleTransitionEngine
    @State private var lastDrag: CGSize = .zero
    @State private var ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    @State private var lastTick = ProcessInfo.processInfo.systemUptime
    @State private var picked: String?

    private var rig: OrbitRig { engine.earthRig }
    private var stop: EarthOrbitCameraStop { engine.earthStop }
    private var phase: Double { engine.earthPhase }

    private var julianDay: Double {
        store.state.space.julianDay
    }

    var body: some View {
        ZStack {
            ChromeTokens.spaceBackground.ignoresSafeArea()

            RealityView { content in
                content.camera = .virtual
                scene.build()
                content.add(scene.root)
                scene.attach(content)
                scene.apply(julianDay: julianDay, phase: phase, rig: rig, stop: stop)
            } update: { _ in
                guard !engine.isTransitioning else { return }
                scene.apply(julianDay: julianDay, phase: phase, rig: rig, stop: stop)
            }
            .coordinateSpace(name: EarthOrbitScene.coordinateSpaceName)
            .gesture(orbitGesture)
            .simultaneousGesture(zoomGesture)
            .simultaneousGesture(selectGesture)

            VStack(alignment: .leading, spacing: 6) {
                Spacer(minLength: 0)
                infoPanel
                    .padding(.horizontal, ChromeTokens.edgePadding)
                    .padding(.bottom, ChromeTokens.horizontalPadding)
            }
        }
        .onAppear(perform: registerActions)
        .onReceive(ticker) { _ in tick() }
    }

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stop == .overview ? "地月系 · 38.4 万 km" : "近地轨道 · 高度约 350 km")
                .font(.system(size: ChromeTokens.primarySize, weight: .semibold))
            Text(EarthOrbitConstants.analogyText)
                .font(.system(size: ChromeTokens.labelSize))
                .foregroundStyle(ChromeTokens.secondaryText)
            Text("天宫一号轨道倾角 42.77° · 一圈约 91.5 分钟")
                .font(.system(size: ChromeTokens.labelSize))
                .foregroundStyle(ChromeTokens.secondaryText)
            if let picked {
                Text(pickedLabel(picked))
                    .font(.system(size: ChromeTokens.labelSize))
                    .foregroundStyle(ChromeTokens.accent)
            }
            if stop == .orbitClose {
                Button {
                    store.dispatch(.descend(.tiangong))
                } label: {
                    Text("进入天宫一号")
                        .font(.system(size: ChromeTokens.labelSize, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(ChromeTokens.accent, in: Capsule())
                        .foregroundStyle(ChromeTokens.spaceBackground)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("进入天宫一号")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ChromeTokens.cardPadding)
        .background(ChromeTokens.surface1.opacity(0.92), in: RoundedRectangle(cornerRadius: ChromeTokens.edgePadding))
    }

    private func pickedLabel(_ name: String) -> String {
        switch name {
        case "earth": return "地球 · 半径 6371 km"
        case "moon": return "月球 · 距地球 38.44 万 km"
        case "tiangong": return "天宫一号 · 点「进入天宫一号」下钻"
        default: return name
        }
    }

    private func registerActions() {
        actions.primary = { id in
            switch id {
            case .earthOrbitOverview:
                engine.earthStop = .overview
                engine.earthRig = EarthOrbitCameraStop.overview.rig
                picked = nil
            default:
                break
            }
        }
        actions.control = { id in
            switch id {
            case .earthOrbitView:
                engine.earthStop = stop == .overview ? .orbitClose : .overview
                engine.earthRig = engine.earthStop.rig
            default:
                break
            }
        }
    }

    private func tick() {
        guard store.state.route == .earthOrbit, !engine.isTransitioning else { return }
        let now = ProcessInfo.processInfo.systemUptime
        lastTick = now
        scene.apply(julianDay: julianDay, phase: phase, rig: rig, stop: stop)
    }

    private var orbitGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                engine.earthRig.rotate(
                    deltaX: Float(value.translation.width - lastDrag.width),
                    deltaY: Float(value.translation.height - lastDrag.height)
                )
                lastDrag = value.translation
            }
            .onEnded { _ in lastDrag = .zero }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                engine.earthRig.dolly(scale: Float(value.magnification))
            }
    }

    private var selectGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                picked = scene.pick(at: value.location)
                if picked == "tiangong", stop == .overview {
                    engine.earthStop = .orbitClose
                    engine.earthRig = EarthOrbitCameraStop.orbitClose.rig
                }
            }
    }
}
