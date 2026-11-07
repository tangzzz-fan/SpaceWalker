import Foundation

enum LaunchMode {
    static let environmentKey = "SPACEWALKER_MODE"
    static let prototypeValue = "prototype"

    static func enabledFeatures(environment: [String: String]) -> [AppFeature] {
        environment[environmentKey] == prototypeValue ? [AppFeature.prototype] : []
    }

    static func autoPlaceEnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_AUTOPLACE"] == "1"
    }

    static func forcedPermission(environment: [String: String]) -> CameraPermissionState? {
        switch environment["SPACEWALKER_FORCE_PERMISSION"] {
        case "denied": .denied
        case "restricted": .restricted
        case "authorized": .authorized
        default: nil
        }
    }

    static func forcedUnavailability(environment: [String: String]) -> SessionUnavailability {
        guard let value = environment["SPACEWALKER_FORCE_DEGRADED"] else {
            return SessionUnavailability()
        }
        switch value {
        case "collision":
            return SessionUnavailability(sceneUnderstanding: [.collision])
        case "all":
            return SessionUnavailability(
                anchors: [.plane],
                sceneUnderstanding: [.collision, .occlusion, .shadow]
            )
        default:
            return SessionUnavailability(sceneUnderstanding: value == "occlusion" ? [.occlusion] : [])
        }
    }
}
