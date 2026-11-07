import RealityKit
import SwiftUI
import TGReduxKit

struct SessionView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    @State private var runner = SessionRunner()
    @State private var placement = PlacementController()
    @State private var ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    #if DEBUG
    private let autoPlace = LaunchMode.autoPlaceEnabled(environment: ProcessInfo.processInfo.environment)
    #endif
    @State private var stableSurfaceTicks = 0
    @State private var placementDebugLine: String?
    @State private var didAutoPlace = false

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack(alignment: .top) {
                RealityView { content in
                    content.camera = .spatialTracking
                    placement.attach(content)
                }
                .coordinateSpace(.named(PlacementController.coordinateSpaceName))
                .ignoresSafeArea()
                .gesture(
                    SpatialTapGesture()
                        .onEnded { _ in placement.place(center: center) }
                )
                .task { await handle(.appeared) }
                .onDisappear {
                    placement.detach()
                    Task { await handle(.disappeared) }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard let event = Self.event(for: phase) else { return }
                    Task { await handle(event) }
                }

                overlay
            }
            .onReceive(ticker) { _ in
                placement.tick(center: center)
                placementDebugLine = placement.debugLine
                #if DEBUG
                stableSurfaceTicks = store.state.placement.isSurfaceAvailable
                    ? stableSurfaceTicks + 1
                    : 0
                if autoPlace,
                   !didAutoPlace,
                   stableSurfaceTicks >= 20 {
                    placement.place(center: center)
                    didAutoPlace = true
                }
                #endif
            }
        }
    }

    private var overlay: some View {
        VStack(spacing: 8) {
            degradedBanner
            statusBanner
            diagnostics
        }
        .padding(.top, 8)
        .animation(.easeOut(duration: 0.2), value: store.state.placement.isSurfaceAvailable)
    }

    @ViewBuilder
    private var degradedBanner: some View {
        if let headline = store.state.session.matrix.headline {
            VStack(spacing: 2) {
                Text(headline)
                    .font(.subheadline.weight(.semibold))
                if let detail = store.state.session.matrix.detail {
                    Text(detail)
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        let placementState = store.state.placement
        let matrix = store.state.session.matrix

        if placementState.needsReplace {
            VStack(spacing: 8) {
                Text("表面丢失，请重新放置")
                    .font(.subheadline)
                Button("重新放置") {
                    placement.reset()
                    store.dispatch(.placement(.reset))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        } else if placementState.isPlaced {
            Text(placementState.driftLine)
                .font(.caption)
                .monospacedDigit()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        } else if matrix.placementStrategy == .unavailable {
            Text("设备不支持放置")
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        } else if placementState.isSurfaceAvailable {
            Text(matrix.placementStrategy == .planeCenter ? "轻点按平面中心放置" : "轻点放置")
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        } else {
            Label("移动手机扫描桌面", systemImage: "viewfinder")
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    @ViewBuilder
    private var diagnostics: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 2) {
            Text(store.state.session.phase.rawValue.uppercased())
                .font(.caption.weight(.semibold))
            if let line = store.state.session.diagnosticLine {
                Text(line)
                    .font(.caption2)
            }
            if !store.state.session.unavailability.cameraAuthorized {
                Text("camera unauthorized")
                    .font(.caption2)
            }
            if let detail = store.state.session.matrix.detail {
                Text("degraded: \(detail)")
                    .font(.caption2)
            }
            if let placementDebugLine {
                Text(placementDebugLine)
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        #endif
    }

    @MainActor
    private func handle(_ event: SessionEvent) async {
        let transition = SessionLifecycle.transition(from: store.state.session.phase, on: event)
        store.dispatch(.session(.phaseChanged(transition.phase)))

        switch transition.command {
        case .start, .resume:
            bindPlacementCallbacks()
            #if DEBUG
            let forced = LaunchMode.forcedUnavailability(
                environment: ProcessInfo.processInfo.environment
            )
            #else
            let forced = SessionUnavailability()
            #endif
            let outcome = await runner.start(forcedUnavailability: forced)
            store.dispatch(.session(.reported(outcome)))
            placement.apply(CapabilityMatrixBuilder.make(from: outcome))
        case .stop:
            await runner.stop()
        case .suspend, .none:
            break
        }
    }

    @MainActor
    private func bindPlacementCallbacks() {
        placement.onSurfaceChanged = { available in
            store.dispatch(.placement(.surfaceAvailable(available)))
        }
        placement.onPlaced = {
            store.dispatch(.placement(.placed))
        }
        placement.onDriftMeasured = { drift in
            store.dispatch(.placement(.driftMeasured(drift)))
        }
        placement.onReplaceNeeded = { needed in
            store.dispatch(.placement(.replacePrompted(needed)))
        }
    }

    private static func event(for phase: ScenePhase) -> SessionEvent? {
        switch phase {
        case .active:
            .becameActive
        case .inactive:
            .becameInactive
        case .background:
            .enteredBackground
        @unknown default:
            nil
        }
    }
}
