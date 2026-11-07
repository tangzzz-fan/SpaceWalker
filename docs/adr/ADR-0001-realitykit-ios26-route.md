# ADR-0001：iOS AR 采用 RealityView + SpatialTrackingSession

- 状态：已接受
- 日期：2026-11-07
- 决策者：项目总监（技术门槛由 Tang 拍板）
- 相关：PRD §9、GLOSSARY「追踪会话 / 能力探测 / 降级模式」

## 背景

iOS 上有两条 AR 路线：成熟的 `ARView` + `ARKit` 配置，以及 iOS 26 起的 `RealityView` + `SpatialTrackingSession`。本项目需要平面锚定、现实遮挡、拖拽/缩放/旋转、海量实例与姿态选中，且基准机型已是 iOS 26.6。

## 决策

采用 `RealityView` + `SpatialTrackingSession`，部署目标 iOS 26.0；`ARView` 不作为主路径。

## 理由

1. `SpatialTrackingSession`（iOS 18+）统一配置追踪、场景理解与相机背景，无需手写 `ARConfiguration`；iOS 默认会话已包含 camera / world / plane / object / image / face 与 occlusion / shadow / collision / physics。
2. `MeshInstancesComponent`（iOS 26+）是 B 阶段海量星点的可行方案，也是部署目标取 26 而非 18 的实际原因。
3. 场景理解的 `.occlusion` 在 iOS 可用，能提供现实遮挡；基准机型实测为 iPhone 16 Pro（有 LiDAR），遮挡效果不再预设降级，由 003 真机实测定档。
4. `ARKitAnchorComponent` 可读取 ARKit 锚点的 transform 与 extent，平面适配更准确（M0 以 SDK 头文件确认）。

## 后果

- 设备门槛 iOS 26（因 `MeshInstancesComponent`）；旧系统不在支持范围。
- iOS **没有** `ManipulationComponent` 与 `EnvironmentBlendingComponent`（均为 visionOS 26+）：拖拽/缩放/旋转必须用 SwiftUI 手势 + 命中组件自行解算；现实遮挡只能依赖场景理解，基准机型有 LiDAR。
- API 较新、社区案例少，必须以真机验证为准；Simulator 不能验证任何 AR 能力。
- 必须在 M0 实现能力探测与降级模式，禁止把"系统版本够"当成"能力可用"。
- Swift 6 严格并发下，会话与实体更新必须收敛到 `@MainActor`，避免跨 actor 传实体。
- iOS 与 visionOS 的 `Configuration` 初始化不同：iOS 只有 `init(tracking:sceneUnderstanding:camera:)`，且 `Camera` 枚举与 `.camera/.face/.body` 锚能力为 iOS 独有；visionOS 走另外两个 `init`。跨平台代码不能照抄。
- 显式 `SpatialTrackingSession.run(_:)` **覆盖**默认能力集：未申请 `.plane` 时 `AnchorEntity(plane:)` 永不锚定。默认会话的"全能力"只在不主动配置时成立。
- `SpatialTrackingSession.Configuration` 未标 `Sendable`，Swift 6 语言模式下传给 `run(_:)` 会报 sending 错误；需 `@preconcurrency import RealityKit`。这是 SDK 缺口，不是本地并发设计问题。

## 替代方案

- **ARView + ARKit**：可下探 iOS 18、资料多；但手势、锚点、遮挡均需自写，且用不上新组件。若 iOS 26 门槛被推翻，回退此方案，代价是 M1 交互层全部重写。
- **SceneKit**：已进入仅修关键 bug 的维护状态，排除。

## 修订记录

- 2026-11-07 v3：真机实测基准机型为 iPhone 16 Pro / iOS 27.0（有 LiDAR），撤回"无 LiDAR 导致遮挡降级"的前提。
- 2026-11-07 v2：修正平台可用性。`ManipulationComponent`、`EnvironmentBlendingComponent` 为 visionOS 26+，iOS 不可用；`SpatialTrackingSession` 为 iOS 18+，部署目标取 26 的实际原因是 `MeshInstancesComponent`。补充基准机型无 LiDAR 的后果。
