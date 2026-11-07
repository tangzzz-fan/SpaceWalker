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

    static func asterismsEnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_ASTERISMS"] == "1"
    }

    static func timeOffsetHours(environment: [String: String]) -> Double? {
        guard let raw = environment["SPACEWALKER_TIMEOFFSET"], let value = Double(raw) else { return nil }
        return min(max(value, -24), 24)
    }

    static func simulatedLocation(environment: [String: String]) -> (latitude: Double, longitude: Double)? {
        guard let latRaw = environment["SPACEWALKER_LAT"],
              let lonRaw = environment["SPACEWALKER_LON"],
              let latitude = Double(latRaw),
              let longitude = Double(lonRaw),
              abs(latitude) <= 90,
              abs(longitude) <= 180
        else { return nil }
        return (latitude, longitude)
    }

    static func finderPreviewEnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_FINDER"] == "1"
    }

    static func tourPreviewEnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_TOUR"] == "1"
    }

    /// 「1」只打开星榜；写部门名直接进该部；写别的词按关键词检索。
    /// 无陀螺仪时用定时器驱动准星判定，便于模拟器验证停留选中与星座识别。
    static func dwellProbeEnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_DWELL"] == "1"
    }

    static func outlinesEnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_OUTLINES"] == "1"
    }

    /// 打开星群层；写 id（如 winter-triangle）则同时把视角对准该星群中心。
    static func patternPreview(environment: [String: String]) -> String? {
        guard let raw = environment["SPACEWALKER_PATTERNS"],
              !raw.isEmpty, raw != "0"
        else { return nil }
        return raw
    }

    /// 一次点亮全部图形层（连线 + 轮廓 + 星官 + 星群），用于真机负载验收。
    static func allLayersEnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_LAYERS"] == "1"
    }

    /// 帧率日志：Debug 构建默认就开——真机验收不该依赖「记得加参数」，
    /// 忘了加就得让人再跑一遍。`SPACEWALKER_FPS=0` 可关。
    static func perfLogEnabled(environment: [String: String]) -> Bool {
        if environment["SPACEWALKER_FPS"] == "0" { return false }
        #if DEBUG
        return true
        #else
        return environment["SPACEWALKER_FPS"] == "1"
        #endif
    }

    /// 屏幕右上角的读数：只在显式打开时显示，避免污染截图。
    static func fpsHUDEnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_FPS"] == "1"
    }

    /// 把星图对准指定星座（缩写，如 Ori），用于模拟器无陀螺仪时的验证。
    static func aimConstellation(environment: [String: String]) -> String? {
        guard let raw = environment["SPACEWALKER_AIM"], !raw.isEmpty, raw != "0" else { return nil }
        return raw
    }

    static func fengshenTarget(environment: [String: String]) -> String? {
        guard let raw = environment["SPACEWALKER_FENGSHEN"],
              !raw.isEmpty, raw != "0"
        else { return nil }
        return raw
    }

    static func finderQuery(environment: [String: String]) -> String {
        environment["SPACEWALKER_QUERY"] ?? ""
    }

    static func guideTarget(environment: [String: String]) -> String? {
        environment["SPACEWALKER_GUIDE"]
    }

    static func regionPreview(environment: [String: String]) -> String? {
        environment["SPACEWALKER_REGION"]
    }

    static func starPreview(environment: [String: String]) -> String? {
        environment["SPACEWALKER_STAR"]
    }

    static func aimTarget(environment: [String: String]) -> String? {
        environment["SPACEWALKER_AIM"]
    }

    static func groupPreview(environment: [String: String]) -> String? {
        environment["SPACEWALKER_GROUP"]
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
