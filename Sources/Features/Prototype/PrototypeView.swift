import RealityKit
import SwiftUI
import TGReduxKit

struct PrototypeView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    @State private var dragStart: SIMD3<Float>?
    @State private var magnifyStart: Float?

    var body: some View {
        ZStack(alignment: .bottom) {
            RealityView { content in
                content.camera = .spatialTracking
                let anchor = AnchorEntity(
                    plane: .horizontal,
                    classification: .any,
                    minimumBounds: [0.2, 0.2]
                )
                anchor.name = "planetAnchor"
                anchor.addChild(PlanetFactory.makePlanet())
                content.add(anchor)
            } update: { content in
                guard
                    let anchor = content.entities.first(where: { $0.name == "planetAnchor" }),
                    let planet = anchor.findEntity(named: "planet")
                else { return }

                let state = store.state.prototype
                planet.position = state.planetPosition
                planet.scale = .one * state.planetScale
            }
            .simultaneousGesture(tapGesture)
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(magnifyGesture)
            .ignoresSafeArea()

            hud
        }
    }

    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                if value.entity.name == "planet" {
                    store.dispatch(.prototype(.select))
                } else {
                    store.dispatch(.prototype(.deselect))
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                guard value.entity.name == "planet" else { return }
                if dragStart == nil {
                    dragStart = store.state.prototype.planetPosition
                }
                guard let start = dragStart else { return }
                let offset = PrototypeLogic.dragOffset(translation: value.translation)
                store.dispatch(.prototype(.move(to: start + offset)))
            }
            .onEnded { _ in
                dragStart = nil
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if magnifyStart == nil {
                    magnifyStart = store.state.prototype.planetScale
                }
                guard let start = magnifyStart else { return }
                store.dispatch(.prototype(.setScale(start * Float(value.magnification))))
            }
            .onEnded { _ in
                magnifyStart = nil
            }
    }

    @ViewBuilder
    private var hud: some View {
        VStack(spacing: 12) {
            if store.state.prototype.phase == .scanning {
                Label("把手机对准桌面，缓慢移动", systemImage: "viewfinder")
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            if store.state.prototype.infoCardVisible {
                PlanetInfoCard()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 32)
        .animation(.easeOut(duration: 0.2), value: store.state.prototype.infoCardVisible)
    }
}

private struct PlanetInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("演示行星")
                .font(.headline)
            Text("直径 12,742 km · 距日 1.00 AU")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("原型阶段：只验证放置、选中与拖拽手感。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }
}
