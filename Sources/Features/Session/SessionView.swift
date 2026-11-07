import RealityKit
import SwiftUI
import TGReduxKit

struct SessionView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var runner = SessionRunner()

    var body: some View {
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
    }

    @MainActor
    private func handle(_ event: SessionEvent) async {
        let transition = SessionLifecycle.transition(from: store.state.session.phase, on: event)
        store.dispatch(.session(.phaseChanged(transition.phase)))

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
