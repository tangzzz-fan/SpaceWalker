# RealityKit iOS 26 一手资料核查

- 核查日期：2026-11-07
- 方法：只采信 Apple Developer Documentation 与 Apple 官方支持页；无法在一手页面确认的条目归入"未证实"。
- 用途：PRD §10 技术决策、ADR-0001、M0 门禁的事实底座。

## 结论摘要

1. `SpatialTrackingSession` 的可用性是 **iOS 18.0+ / iPadOS 18.0+ / visionOS 2.0+**，不是 iOS 26 起。iOS 默认会话为 `tracking: [.camera, .world, .plane, .object, .image, .face]`、`sceneUnderstanding: [.occlusion, .shadow, .collision, .physics]`、`camera: .back`。
2. `RealityView` 在 iOS 上把 `camera` 设为 `.spatialTracking` 后，相机画面作为背景显示；锚定、遮挡、阴影由会话配置驱动。
3. `ManipulationComponent` 是 **visionOS 26.0+**，iOS 不可用；iOS 的拖拽/缩放/旋转必须用 SwiftUI 手势 + 命中组件 + 自行解算 Transform。
4. `EnvironmentBlendingComponent` 是 **visionOS 26.0+**，且只在混合/渐进沉浸空间生效；iOS 的现实遮挡只能依赖 `sceneUnderstanding: [.occlusion]`。
5. `MeshInstancesComponent` 是 **iOS 26.0+ / iPadOS 26.0+ / macOS 26.0+ / tvOS 26.0+ / visionOS 26.0+**；实例数据是 `LowLevelInstanceData`，不是 `Entity`，不能逐实例挂 `CollisionComponent` / `InputTargetComponent`。
6. **iPhone 16 没有 LiDAR**（Apple 中国官网对比页中 iPhone 16 的激光雷达扫描仪为"不适用"，iPhone 16 Pro 才有）。基准机型无 LiDAR，房间网格重建与真实遮挡能力受限。
7. 天宫一号于 2011-09-29 发射，是中国首个目标飞行器/空间实验室，先后与神舟八号、九号、十号共完成 6 次交会对接，2016-03-16 终止数据服务，2018-04-02 再入大气层（落区南太平洋中部）。

## 事实表

| 主题 | 事实 | 一手来源 | 平台/版本 | 对 PRD 的影响 |
|---|---|---|---|---|
| 追踪会话 | `SpatialTrackingSession` 管理世界/平面/图像/物体/人脸追踪，并为 iOS 配置相机与场景理解 | https://developer.apple.com/documentation/realitykit/spatialtrackingsession | iOS 18.0+ | 部署目标可选 26，但"iOS 26 才有 AR"的说法错误，ADR 理由需改 |
| 默认会话 | iOS 未手动配置时使用 camera/world/plane/object/image/face + occlusion/shadow/collision/physics + 后置相机 | 同上（Use the default spatial tracking session） | iOS 18.0+ | 能力探测仍必须做，不能把默认值当保证 |
| 相机背景 | `camera` 设为 `.spatialTracking` 后 RealityView 显示相机画面 | 同上（Overview） | iOS 18.0+ | A 阶段视图层方案成立 |
| 能力探测 | `run(_:)` 返回 `UnavailableCapabilities?`，含不支持与未授权两类 | 同上 | iOS 18.0+ | FR-X-02 的降级依据成立 |
| 操纵组件 | `ManipulationComponent` 提供手势移动、旋转、缩放与音频反馈 | https://developer.apple.com/documentation/realitykit/manipulationcomponent | **visionOS 26.0+** | iOS 不可用；A 阶段交互需自研，ADR 与 §10 必须改 |
| 遮挡组件 | `EnvironmentBlendingComponent` 让现实物体遮挡虚拟内容 | https://developer.apple.com/documentation/realitykit/environmentblendingcomponent | **visionOS 26.0+**，且仅混合/渐进沉浸空间 | iOS 不可用；改用场景理解的 `.occlusion` |
| 实例组件 | `MeshInstancesComponent` 对同一实体的模型做 GPU 实例化，实例变换在实体局部空间 | https://developer.apple.com/documentation/realitykit/meshinstancescomponent | **iOS 26.0+** | B 阶段方案成立；但实例不是 Entity |
| 实例命中 | 实例是 `LowLevelInstanceData`，文档称其"像子实体"，但没有独立 Entity 身份 | 同上（Overview） | iOS 26.0+ | 逐星命中不能用 Collision/InputTarget，需屏幕投影 + 解析判定 |
| 手势命中 | 实体接收输入需要 `InputTargetComponent`；`CollisionComponent` 定义可交互区域 | https://developer.apple.com/documentation/realitykit/inputtargetcomponent | iOS 13.0+ | A/C 阶段命中方案成立；B 阶段例外 |
| 设备能力 | iPhone 16 无激光雷达扫描仪；iPhone 16 Pro 有 | https://www.apple.com.cn/iphone/compare/?modelList=iphone-16,iphone-16-pro,iphone-16-pro-max | 硬件 | 基准机型无 LiDAR，遮挡承诺必须降级 |
| 史实 | 2011-09-29 发射；目标飞行器/首个空间实验室；与神舟八/九/十号 6 次对接；2016-03-16 终止数据服务；2018-04-02 再入 | https://www.cmse.gov.cn/xwzx/202209/t20220921_50802.html | — | C 阶段文案与信息卡必须据此，不得称"空间站" |

## 必须标注为"待真机验证"

- 无 LiDAR 的 iPhone 16 上 `.occlusion` 的实际效果（能否挡住桌沿、手掌、杯子）。
- 2000 个透明/半透明实例在基准机型上的帧时间、过绘制与发热。
- `MeshInstancesComponent` 是否支持逐实例材质或逐实例 LOD（当前文档只给出统一网格 + 变换列表）。
- 姿态视锥选中的角度阈值与停留时间的手感（3° / 0.6s 只是起点）。
- C 阶段 1:20 尺度下，0.05m/s 的速度容差在触控操作下是否可达。

## 未证实

- `ARKitAnchorComponent` 与 `AnchorStateEvents` 在 iOS 26 的完整 API 形状与版本约束：WWDC25 摘要提及，但本次未在独立文档页确认，M0 需以 SDK 头文件为准。
- `MeshInstancesComponent` 是否参与物理与碰撞：文档未提及，按"不参与"设计。
- iPhone 16 在 iOS 26 上是否支持 `.sceneUnderstanding` 的网格重建：无 LiDAR 时预计仅平面级，未证实。
