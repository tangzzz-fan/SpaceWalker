import Foundation
import TGReduxKit
import simd

enum PrototypePhase: String, Equatable, Sendable {
    case scanning
    case placed
}

struct PrototypeState: State {
    var phase: PrototypePhase = .scanning
    var planetPosition: SIMD3<Float> = .zero
    var planetScale: Float = 1
    var isSelected = false
    var infoCardVisible = false
}

enum PrototypeAction: Action {
    case anchored
    case select
    case deselect
    case move(to: SIMD3<Float>)
    case setScale(Float)
    case reset
}

enum PrototypeReducer {
    static func reduce(_ state: inout PrototypeState, _ action: PrototypeAction) {
        switch action {
        case .anchored:
            state.phase = .placed
        case .select:
            state.isSelected = true
            state.infoCardVisible = true
        case .deselect:
            state.isSelected = false
            state.infoCardVisible = false
        case .move(let position):
            state.planetPosition = PrototypeLogic.clampPosition(position)
        case .setScale(let scale):
            state.planetScale = PrototypeLogic.clampScale(scale)
        case .reset:
            state = PrototypeState(phase: state.phase)
        }
    }
}
