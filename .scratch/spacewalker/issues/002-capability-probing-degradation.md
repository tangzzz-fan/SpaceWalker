---
id: 002
title: 能力探测与降级
status: ready-for-agent
stage: M0
blocked_by: [001]
---

## 背景

`run(_:)` 返回 `UnavailableCapabilities?`，包含"不支持"与"未授权"两类。必须把它变成可执行的分支，而不是把默认配置当保证。

## 验收标准

- [ ] 启动后日志打印：请求的能力、可用能力、不可用能力（含原因分类）。
- [ ] 当遮挡/物理/阴影不可用时，自动进入降级模式，HUD 显示"降级模式"。
- [ ] 降级模式下不调用依赖缺失能力的功能，不崩溃。
- [ ] 能力映射有单元测试：至少覆盖"全可用""全不可用""部分可用"三种输入。
- [ ] 真机证据：完整模式与降级模式各一张截图 + 日志片段。

## 测试缝

- `CapabilityMatrix`：输入 `UnavailableCapabilities` → 输出降级开关集合与 HUD 文案（纯函数）。

## 备注

- 不得用 `#available` 代替能力探测：系统版本够不等于设备能力可用。
- 基准机型无 LiDAR，遮挡能力预期会降级，属已知情况。

## 实现进展（2026-11-07）

五项验收全部有 agent 侧证据，状态流转待人工确认。

- `CapabilityMatrix`：输入请求能力 + `UnavailabilityCapabilities` → 输出 `mode`、`reasons`、`canAnchorToPlanes`、`canHitRealSurfaces`、`placementStrategy`、HUD 文案；单测覆盖全可用 / 全不可用 / 部分可用 / 未请求能力不计降级 / 由 outcome 推导。
- 日志：`session.request`（请求）、`session.started`（授予 + 不可用）、`session.matrix`（模式 + 原因 + 策略）三段落到 `Documents/session.log`，可按 `[ms]` 排序。
- 降级行为：`surfaceHit` → `planeCenter` → `unavailable` 三档策略，缺失能力时不再调用对应接口；完全不可用时拒绝放置并写 `placement.blocked`。
- 真机证据：`002-full-mode.jpg`、`002-degraded-collision.jpg`、`002-degraded-unavailable.jpg` + 三份日志，见 `docs/gates/M0/`。
- 备注：基准机型三类能力全可用，降级路径靠 `SPACEWALKER_FORCE_DEGRADED` 注入复现；真实缺能力设备的验证要等非 LiDAR 机型。
