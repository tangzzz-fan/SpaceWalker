---
id: 076
title: 诊断开关唯一来源与诊断面板
status: ready-for-agent
stage: M3
blocked_by: [075]
---

## 背景

把散落两处的开关读法统一成一个可注入的纯函数：主界面默认不显示 fps、pick 自检、坐标系状态，长按版本号 3 秒才进诊断面板。开发者仍能一键打开全部取证开关，但普通用户永远看不到调试串。

父 spec：074。

## 验收标准

- [x] `LaunchMode` 新增纯函数作为诊断开关唯一来源，接收环境字典，可在单测里注入
- [x] 收编 `SPACEWALKER_TG_*`（字典注入）与 `SPACEWALKER_FLAG_*`（直接读 `ProcessInfo`）的不一致
- [x] `ChromeState.debugOverlay` 默认全 false；三个主界面零 fps / pick / 坐标状态渲染
- [x] 长按版本号 3 秒进入诊断面板，面板内可见原有取证数据
- [x] 既有取证开关（NOLABEL / PHASE / FREEZE / CUTAWAY / REENTRY / DRAWING 等）行为不变
- [x] 单测覆盖开关纯函数与 `debugOverlay` 默认值；358 项既有测试全绿

## 测试缝

`LaunchMode` 纯函数 + `ChromeState.debugOverlay`，reducer 断言通道；先例 `SkyTests` 里的调试开关断言。

## 备注

- 父票 075：直接复用它建立的 `ChromeState`，不另起状态容器。
- 诊断面板入口是唯一允许的调试数据出现位置；主界面「0 处」需可断言，不能只靠截图。
- 每步完成后提交，commit message 引用 076。

## 实施证据（agent 自验，状态流转仍由人确认）

- TDD 红灯 `/tmp/spacewalker-076-red.log`：编译失败 10 处，均为新 API 未实现（`LaunchMode.diagnostics` / `AppFeature.override` / `ChromeState.debugOverlay` / `AppAction.chrome`）。
- 绿灯 `/tmp/spacewalker-076-green2.log`：`xcodebuild test -scheme SpaceWalker -destination 'platform=iOS Simulator,name=iPhone 18 Pro'` → **369 项、0 失败**（075 的 361 + 8 条新断言）。
- 静态扫描：`grep -rnE 'Text\((fpsLine|probeLine|"pick ·|perfSummary|fpsOnlyLine)' Sources/` → **0 处**；三个主视图的 fps / pick 读数改为只写 `SessionLog`，不再进 View。
- 截图 `docs/gates/M3/076-default.png` 与 `076-debug-switches-on.png`（`SPACEWALKER_FPS=1 PICKPROBE=1 COORDS=1`）：**MD5 均为 `a4db0ad5cd06a0210c88caae2826e866`，像素完全一致**，证明调试开关不再改变主界面。
- 截图 `docs/gates/M3/076-diagnostics-panel.png`（`SPACEWALKER_DIAGNOSTICS=1` 无头取证）：面板显示开关状态、启动参数、最近 40 行运行日志；正式入口为长按版本号 3 秒。
- 兼容：`fpsHUDEnabled` / `pickProbeEnabled` / 所有 `SPACEWALKER_TG_*` 原函数签名与行为不变；`AppFeature` 改用可注入 `override(environment:)`，`LaunchMode.environment()` 是唯一读取 `ProcessInfo` 的入口。
- 遗留：`SPACEWALKER_COORDS` 只作为诊断面板里的一个读数开关，没有对应的主界面渲染（这是本票刻意的）；`LaunchMode.diagnostics` 的 `overrides` 会把启动参数明文列在面板里，面板本身不对外入口暴露给普通用户。
