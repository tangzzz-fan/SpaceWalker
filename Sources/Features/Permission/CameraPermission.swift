import AVFoundation
import Foundation

enum CameraPermissionState: String, Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted

    static func from(_ status: AVAuthorizationStatus) -> CameraPermissionState {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .denied
        }
    }
}

enum PermissionScreen: Equatable, Sendable {
    case content
    case requesting
    case explanation(showsSettings: Bool)
}

enum PermissionGate {
    static func screen(for status: CameraPermissionState) -> PermissionScreen {
        switch status {
        case .authorized: .content
        case .notDetermined: .requesting
        case .denied: .explanation(showsSettings: true)
        case .restricted: .explanation(showsSettings: false)
        }
    }

    static func shouldRequestAccess(
        status: CameraPermissionState,
        alreadyRequested: Bool
    ) -> Bool {
        status == .notDetermined && !alreadyRequested
    }
}
