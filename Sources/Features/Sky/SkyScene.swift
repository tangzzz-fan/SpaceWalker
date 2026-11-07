import Foundation
import RealityKit
import simd
import SwiftUI

@MainActor
final class SkyScene {
    enum InputSource {
        case manual
        case attitude
    }

    static let coordinateSpaceName = "sky"
    static let space = NamedCoordinateSpace.named(coordinateSpaceName)

    private(set) var root = Entity()
    var content: RealityViewCameraContent?
    var cameraEntity: Entity?
    /// 垂直视场角。默认 60°，和人眼一支手臂看出去的宽度接近。
    var fieldOfView: Float = SkyScene.defaultFieldOfView
    /// 当前方向下的「默认视场」：竖屏 60°，转横屏后按高度比例变成 31°。
    /// 双击复位要回到这个值，而不是死板的 60°——否则横屏一复位就缩一半。
    var baseFieldOfView: Float = SkyScene.defaultFieldOfView
    var nodes: [Star] = []
    var field = Entity()
    var constellationNode: Entity?
    var silhouetteNode: Entity?
    var constellationCount = 0
    var constellationsRequested = true
    var silhouettesRequested = false
    var constellationShapes: [OutlineShape] = []
    var constellationHighlightNode: Entity?
    var constellationHighlightID: String?
    var constellationPositions: [String: SIMD3<Float>] = [:]
    var asterismNode: Entity?
    var asterismMaterial: UnlitMaterial?
    var asterismHighlightNode: Entity?
    var asterismHighlightID: String?
    var starsByHIP: [Int: Star] = [:]
    var asterismSegmentCount = 0
    var asterismsRequested = false
    var patternNode: Entity?
    var patternMaterial: UnlitMaterial?
    var patternShapes: [OutlineShape] = []
    var patternHighlightNode: Entity?
    var patternHighlightID: String?
    var patternSegmentCount = 0
    var patternsRequested = false
    var isBuilt = false
    var viewSize: CGSize = .zero
    /// 谁在驱动朝向。两把锁（aimLocked / isAttitudeDriven）会互相堵死：
    /// 定位后锁住姿态，而姿态可用时又禁掉拖动，画面就冻住了。
    var source: InputSource = .manual
    /// 跳转产生的偏移，写在星空坐标系里：跟随姿态时也要能「把某个方向摆到屏幕中心」。
    var aimDelta = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    /// 界面方向造成的画布旋转。竖屏 0，横屏 ±90°。
    var interfaceRoll: Float = 0
    /// 最近一次设备姿态推出的场景朝向，跳转偏移与界面补偿都以它为基准。
    var attitudeBase: simd_quatf?

    var starCount: Int {
        nodes.count
    }

    var selectableCount: Int {
        nodes.filter(\.isSelectable).count
    }

    var isReady: Bool {
        content != nil && !nodes.isEmpty && viewSize.width > 0
    }

    func resize(_ size: CGSize) {
        let previous = viewSize
        guard size.width > 1, size.height > 1 else {
            viewSize = size
            return
        }
        viewSize = size

        // 转屏时保住「每点多少度」：竖屏 60° 的视场转到横屏该变成 31°，
        // 否则一横过来整片星空缩成一半，像被人拉远了。捏合缩放同样按比例带过去。
        let flipped = (previous.width < previous.height) != (size.width < size.height)
        guard flipped, previous.height > 1 else { return }
        let ratio = Float(size.height / previous.height)
        baseFieldOfView = min(
            Self.maxFieldOfView,
            max(Self.minFieldOfView, baseFieldOfView * ratio)
        )
        setFieldOfView(fieldOfView * ratio)
    }

    // MARK: - 常量
    static let patternColor = SIMD3<Float>(0.80, 0.66, 0.98)
    static let patternTubeRadius: Float = 0.018
    static let patternHighlightTubeRadius: Float = 0.024
    static let patternRadius3D: Float = 49.0
    static let patternHighlightRadius3D: Float = 48.8
    static let patternBaseBrightness: Float = 0.60
    static let patternDimBrightness: Float = 0.18
    static let patternHighlightBrightness: Float = 1.0

    static let asterismColor = SIMD3<Float>(0.88, 0.76, 0.52)
    static let asterismRadius: Float = 0.026
    static let asterismHighlightRadius: Float = 0.03
    static let asterismRadius3D: Float = 49.4
    static let asterismHighlightRadius3D: Float = 49.2
    static let asterismBaseBrightness: Float = 0.52
    static let asterismDimBrightness: Float = 0.16
    static let asterismHighlightBrightness: Float = 0.98
    /// 视场范围：16° 能把人马座整个塞满屏幕，95° 用来纵览银河。
    static let defaultFieldOfView: Float = 60
    static let minFieldOfView: Float = 16
    static let maxFieldOfView: Float = 95

    /// 线的世界半径。0.032 在半径 50 的球面上只占 0.037°，60° 视场里约 0.5pt，
    /// 比星点细二十倍——这才是「骨架摆着却看不出来」的真实原因，不是数据不够。
    static let constellationRadius: Float = 0.088
    static let constellationFillRadius: Float = 51.4
    static let constellationOutlineRadius: Float = 50.6
    /// 高亮层要落在星座线（半径 50）的内侧才不会被原线挡住。
    static let constellationHighlightRadius: Float = 49.6

    // MARK: - 共用

    func uiColor(_ rgb: SIMD3<Float>, brightness: Float) -> UIColor {
        UIColor(
            red: CGFloat(rgb.x) * CGFloat(brightness),
            green: CGFloat(rgb.y) * CGFloat(brightness),
            blue: CGFloat(rgb.z) * CGFloat(brightness),
            alpha: 1
        )
    }
}
