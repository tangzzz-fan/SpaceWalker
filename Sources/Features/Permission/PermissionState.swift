import TGReduxKit

struct PermissionState: State {
    var status: CameraPermissionState = .notDetermined
    var requestedThisLaunch = false

    var screen: PermissionScreen {
        PermissionGate.screen(for: status)
    }
}

enum PermissionAction: Action {
    case status(CameraPermissionState)
    case requested
}

enum PermissionReducer {
    static func reduce(_ state: inout PermissionState, _ action: PermissionAction) {
        switch action {
        case .status(let status):
            state.status = status
        case .requested:
            state.requestedThisLaunch = true
        }
    }
}
