import Foundation

enum PermissionCopy {
    static let deniedTitle = "需要相机才能看见太空"
    static let deniedBody = """
    SpaceWalker 把星图叠加在你眼前的真实桌面上，因此必须使用后置相机。
    画面只在本机实时处理，不录制、不上传。
    """
    static let restrictedTitle = "相机被系统限制"
    static let restrictedBody = """
    当前设备的相机访问被“屏幕使用时间”或设备管理策略限制。
    请让设备管理者解除限制后再打开本应用。
    """
    static let settingsButton = "去设置开启相机权限"
    static let requestingTitle = "正在请求相机权限"
    static let requestingBody = "系统会弹出一次授权提示，请选择“允许”。"
}
