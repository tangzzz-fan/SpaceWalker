import Foundation

enum LaunchMode {
    static let environmentKey = "SPACEWALKER_MODE"

    static func initialRoute(environment: [String: String]) -> AppRoute {
        switch environment[environmentKey] {
        case "sky": .sky
        case "tiangong": .tiangong
        default: .solarSystem
        }
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

    /// 关掉星座层，用于无头验收星官接管（星官只在星座与星群都未命中时参与）。
    static func constellationLayerEnabled(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_NOCONST"] != "1"
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

    /// 启动时的垂直视场角（度）。验收「看全」效果用，比如 85 看整片银河、
    /// 22 把天鹅座塞满屏幕。
    static func fieldOfView(environment: [String: String]) -> Float? {
        guard let raw = environment["SPACEWALKER_FOV"], let value = Float(raw) else { return nil }
        return value
    }

    /// 直接弹出某个星座的识别卡（写缩写，如 Sgr）。准星落点常有星，星卡会
    /// 抢在前面；验收卡片排版时需要一条不经准星的通道。
    static func constellationPreview(environment: [String: String]) -> String? {
        environment["SPACEWALKER_CONSTELLATION"]
    }

    static func groupPreview(environment: [String: String]) -> String? {
        environment["SPACEWALKER_GROUP"]
    }

    static func tiangongDistance(environment: [String: String]) -> Float? {
        environment["SPACEWALKER_TG_DIST"].flatMap(Float.init)
    }

    /// 无头截图用：启动即分离指定部件，逗号分隔（lab,leftWing）。
    static func tiangongSeparated(environment: [String: String]) -> Set<TiangongModuleID> {
        guard let raw = environment["SPACEWALKER_TG_SEPARATED"] else { return [] }
        return Set(raw.split(separator: ",").compactMap { TiangongModuleID(rawValue: String($0)) })
    }

    static func tiangongDockingOnLaunch(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_TG_DOCK"] == "1"
    }

    static func asterismBrowserOnLaunch(environment: [String: String]) -> Bool {
        environment["SPACEWALKER_ASTERISMS"] == "1"
    }
}
