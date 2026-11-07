---
id: 001
title: 会话与相机背景骨架
status: ready-for-agent
stage: M0
blocked_by: [000]
---

## 背景

M0 的第一块砖：用 `RealityView` + `SpatialTrackingSession` 把相机画面显示出来，确认 iOS 26 真机上这条路线能跑通。此 ticket 不做任何业务内容，只做"能看见真实世界"。

## 验收标准

- [ ] 真机启动后 1.0s 内出现相机背景（NFR-02 第一级），无黑屏、无闪退。
- [ ] 会话使用后置相机，`camera` 设为 `.spatialTracking`。
- [ ] 前后台切换 5 次、来电中断 1 次、锁屏 1 次，恢复后画面与内容原位（FR-X-03）。
- [ ] 退出页面时会话停止，无残留。
- [ ] 编译零警告（AppIntents 元数据警告除外；工程约束，不占 PRD 验收）。

## 测试缝

- 会话配置构造：给定能力清单 → 输出 `Configuration`（纯函数，Simulator 可测）。
- 生命周期状态机：前台/后台/中断 → 期望动作（纯函数）。

## 备注

- 不在本 ticket 做平面检测、锚定与 UI。
- 若真机黑屏，先查相机权限与 `camera` 配置，再查 `run(_:)` 返回值。

## 实现进展（2026-11-07）

代码已就绪，真机验收未做，本票保持未完成。

- 实现：`Sources/Features/Session/`（`SessionPlan` / `SessionLifecycle` / `SessionState` / `SessionRunner` / `SessionView`），默认入口仍是 000 原型；关闭 `AppFeature.prototype` 即进入 `SessionView`。
- 已实测（真机 iPhone 16 Pro / iOS 27.0）：会话 `RUNNING`，`anchors=2`（world + camera）、`scene=0`、`unavailable=0`，启动 → `run` 返回 **655ms**，相机背景可见；证据 `docs/gates/M0/evidence-2026-11-07.md` 与 `001-session-running-655ms.jpg`。
- 已实测（Simulator / device）：编译零错误零警告（AppIntents 元数据警告除外）；单测 36 项 0 失败。
- 待真机：首帧上屏耗时（655ms 是 `run` 返回，不等于首帧）、前后台 5 次、来电 1 次、锁屏 1 次、退出释放。
- 会话要求：M0 只申请 `[.world, .camera]`、无场景理解、后置相机；`run(_:)` 返回的不可用能力落到 `SessionState.unavailability` 并打日志。
- 与 000 的关系：本票 `blocked_by: [000]`，但会话与生命周期不随体验结论变化，故提前实现以尽早暴露真机链路风险；000 的记录跑完后，本票结论若与预期不符（如 `.camera` 能力不可用导致黑屏），先改本票再改 003。
- SDK 约束：`SpatialTrackingSession.Configuration` 未标 `Sendable`，Swift 6 下传给 `run(_:)` 报 sending 错误，已用 `@preconcurrency import RealityKit` 处理，记入 ADR-0001 后果。
