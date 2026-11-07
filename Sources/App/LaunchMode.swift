import Foundation

enum LaunchMode {
    static let environmentKey = "SPACEWALKER_MODE"
    static let prototypeValue = "prototype"
    static let arValue = "ar"

    enum AppMode: String, Equatable, Sendable {
        case space
        case ar
        case prototype
    }

    static func mode(environment: [String: String]) -> AppMode {
        switch environment[environmentKey] {
        case prototypeValue: .prototype
        case arValue: .ar
        default: .space
        }
    }

    static func initialRoute(environment: [String: String]) -> AppRoute {
        environment[environmentKey] == "sky" ? .sky : .solarSystem
    }

    static func skyMotionEnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_SKYMOTION"] != "0"
    }

    static func pickProbeEnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_PICKPROBE"] == "1"
    }

    static func autoAlignEnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_ALIGN"] == "1"
    }

    static func finderPreviewEnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_FINDER"] == "1"
    }

    static func guideTarget(environment: [String: String]) -> String? {
        environment["SPACEWALKER_GUIDE"]
    }

    static func regionPreview(environment: [String: String]) -> String? {
        environment["SPACEWALKER_REGION"]
    }

    static func autoAREnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_AUTOAR"] == "1"
    }

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
