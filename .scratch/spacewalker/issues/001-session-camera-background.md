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
