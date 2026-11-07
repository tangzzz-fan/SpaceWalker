import RealityKit
import SwiftUI
import TGReduxKit

struct SessionView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var runner = SessionRunner()

    var body: some View {
        ZStack(alignment: .top) {
            RealityView { content in
                content.camera = .spatialTracking
            }
            .ignoresSafeArea()
            .task { await handle(.appeared) }
            .onDisappear {
                Task { await handle(.disappeared) }
            }
            .onChange(of: scenePhase) { _, phase in
                guard let event = Self.event(for: phase) else { return }
                Task { await handle(event) }
            }

            diagnostics
        }
    }

    @MainActor
    private func handle(_ event: SessionEvent) async {
        let transition = SessionLifecycle.transition(from: store.state.session.phase, on: event)
        store.dispatch(.session(.phaseChanged(transition.phase)))
        #if DEBUG
        NSLog("[SpaceWalker] session phase=%@ event=%@", transition.phase.rawValue, String(describing: event))
        #endif

        switch transition.command {
        case .start, .resume:
            let outcome = await runner.start()
            store.dispatch(.session(.reported(outcome)))
        case .stop:
            await runner.stop()
        case .suspend, .none:
            break
        }
    }

    @ViewBuilder
    private var diagnostics: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 4) {
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
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        #endif
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
