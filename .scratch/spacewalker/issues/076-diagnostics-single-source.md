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

- [ ] `LaunchMode` 新增纯函数作为诊断开关唯一来源，接收环境字典，可在单测里注入
- [ ] 收编 `SPACEWALKER_TG_*`（字典注入）与 `SPACEWALKER_FLAG_*`（直接读 `ProcessInfo`）的不一致
- [ ] `ChromeState.debugOverlay` 默认全 false；三个主界面零 fps / pick / 坐标状态渲染
- [ ] 长按版本号 3 秒进入诊断面板，面板内可见原有取证数据
- [ ] 既有取证开关（NOLABEL / PHASE / FREEZE / CUTAWAY / REENTRY / DRAWING 等）行为不变
- [ ] 单测覆盖开关纯函数与 `debugOverlay` 默认值；358 项既有测试全绿

## 测试缝

`LaunchMode` 纯函数 + `ChromeState.debugOverlay`，`TestStore`；先例 `SkyTests` 里的调试开关断言。

## 备注

- 父票 075：直接复用它建立的 `ChromeState`，不另起状态容器。
- 诊断面板入口是唯一允许的调试数据出现位置；主界面「0 处」需可断言，不能只靠截图。
- 每步完成后提交，commit message 引用 076。
