---
id: 063
title: 移除 AR 入口与整条相机链路
status: done
stage: A
blocked_by: []
---

## 为什么

iOS 26 上，「父视图挂着 RealityView，`fullScreenCover` 里再建一个 `.spatialTracking` 的 RealityView」
会让内层相机画面全黑。Apple 开发者论坛 786543 记录同一组合，Apple 工程师在帖中确认需要提 FB——
是系统回归，不是用法错误。

实测证据（iPhone 16 Pro / iOS 26.6）：

| 观测点 | 结果 |
|---|---|
| 相机授权 | `ar.tilt camera=3` = authorized |
| ARKit 是否在跑 | `placement.apply planes=true surfaces=true`，能检测平面 |
| 渲染 | `anchors 3 · scene 3 · unavailable 0 · 60fps` |
| 画面 | 全黑 |

结论：ARKit 有数据 ≠ passthrough 在渲染，两者是独立层，只有画面能给出判决。

两次绕行都失败并引入回归，已回退：

1. AR 期间卸载底层 RealityView + `root.removeFromParent()` → 仍黑，且**退出 AR 后太阳系空白**
   （RealityView 的 make 未重跑，root 没回到新 scene）。
2. 去掉 `fullScreenCover` 改 ZStack 同层覆盖 → 仍黑，回归依旧。

## 决定

暂时整体移除 AR，而不是留一个黑屏按钮。

## 删除清单（可经 git 历史恢复）

- `Features/Session/`：SessionView、SessionRunner、SessionLifecycle、SessionPlan、SessionState、CapabilityMatrix
- `Features/Placement/`：PlacementController、PlacementFactory、PlacementMath、PlacementState
- `Features/Permission/`：CameraPermission、PermissionCopy、PermissionState、PermissionView
- `Features/Prototype/`：PrototypeView、PrototypeState、PrototypeLogic、PlanetFactory
- `AppState` 的 prototype / session / placement / permission 四个切片与对应 Action
- `LaunchMode` 的 `.ar` / `.prototype` 模式、`AUTOAR` / `AUTOPLACE` / `FORCE_PERMISSION` / `FORCE_DEGRADED` 开关
- `AppFeature.prototype` 与 `FeatureFlags.prototypeEnabled`
- `NSCameraUsageDescription`（应用不再请求相机）
- 测试：CapabilityMatrix、PermissionGate、PlacementMath、PlacementReducer、PrototypeLogic、SessionLifecycle、SessionPlan

保留：`SessionLog`（全仓日志）、`AppClock`、`Features/Probes`（B 阶段用）。

## 验收

- [x] 太阳系底栏不再有相机图标；截图确认只剩 暂停 / 滑块 / 轨道环 / 重置 / 星图 / 信息。
- [x] 星空页不受影响：2996 颗恒星、星座连线、六个入口齐全。
- [x] 268 项测试 0 失败（删掉 65 项 AR 用例）。
- [x] 构建产物与源码中均无 `NSCameraUsageDescription`；`Sources/` 不再 import AVFoundation。
- [x] PRD v0.9 记录决策与恢复条件。

## 恢复条件

Apple 修复该回归，或改用 `ARView`（UIKit 路径 + 显式 session）并能自证 passthrough 渲染。
恢复时从本票的删除清单按 git 历史取回，不要重写。
