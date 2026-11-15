---
id: 078
title: 选中进 Store、标签与信息卡
status: ready-for-agent
stage: M3
blocked_by: [077]
---

## 背景

让「选中」只有一条路径：三个模块的选中都通过 Store action 通知，标签与信息卡由 `ChromeState` 派生。天宫默认一个浮标都没有，点中实验舱才出那一个标签；信息卡从底部升起、可下滑关闭、不遮挡主操作。

父 spec：074。

## 验收标准

- [x] 星图 / 太阳系 / 天宫选中统一 dispatch 进 Store；View 不再各自用 `@State` + `if` 决定标签与卡片
- [x] `selected == nil` → `visibleLabels` 空且 `infoCard == nil`；选中实验舱 → `visibleLabels == [.lab]` 且 `infoCard != nil`
- [x] 天宫默认态零浮标；选中只出该模块一个标签 + 一条引线
- [x] 信息卡高度 ≤32% 屏高、下滑可关、停在主操作上方
- [x] 既有对接 / 剖面 / 工程图 / 再入 / 轨道时钟行为零回归，相关测试全绿
- [x] 358 项既有测试全绿 + 新增 `ChromeState` 选中派生断言

## 测试缝

`ChromeState` 选中派生 + reducer 断言通道；session 行为沿用既有单测，不新开缝。

## 备注

- 父票 077。这是本次唯一跨 session / scene 边界的改动，动手前先确认既有 session 接口未被破坏。
- 标签降级（常驻 → 选中才显示）的最终结论由人工门禁 080 的盲测承接，本票不自行宣告体验达标。
- 每步完成后提交，commit message 引用 078。

## 实施证据（agent 自验，状态流转仍由人确认）

- 红灯 `/tmp/spacewalker-078-red.log`：`ChromeInfoCard` 缺 `maxHeightRatio / placement` 规格字段，编译失败 3 处；其余选中派生在 077 建 `ChromeState` 时已按 074 spec 决策 1 提前落地，属绿灯。
- 绿灯 `/tmp/spacewalker-078-final.log`：**382 项、0 失败**（077 的 377 + 5 条选中派生断言）。
- 截图 `docs/gates/M3/078-C1-zero-labels.png`：天宫默认态模型上 **0 个浮标**；`078-C2-selected-card.png` / `078-C2-separated.png`：选中实验舱只出 1 个标签 + 1 条引线，信息卡停在主操作上方不遮挡；`078-A1-default.png` / `078-B2-body-card.png`：星图默认、太阳系选中土星的信息卡。
- 主操作文案随真实状态：`ChromeState.derive` 增加 `separation: Set<String>` 输入，未分离显示「分离」、已分离显示「装回」（对齐稿 C2），不再出现「按钮写装回、点下去却分离」的反向语义。新增 `SPACEWALKER_TG_SELECT` 无头取证开关。
- 下滑关闭：临时 XCUITest `/tmp/spacewalker-078-swipe-probe2.log` 用坐标拖拽 **1 test passed / 15.0s**，断言卡片消失且主操作回到「开始拆解」。第一次用 `swipeDown()` 得到假失败，本质是取证手势位移不足，已记入全局账本 `2026-11-15-XCUITest_swipeDown在屏幕底部元素上位移不足被误判为功能失效.md`；实现保留 `chrome.card.drag dy=` 日志埋点。
- 不回归取证：`078-C5-cutaway.png` / `078-C6-drawing.png` / `078-C7-reentry.png`，剖面 / 工程图 / 再入三个模式的底部三段仍在、主操作分别为「退出剖面」「退出工程图」「跳过」。同时删掉了再入浮层里与底部重复的「跳过」按钮，保证主操作唯一。
- 遗留：`ChromeInfoCard.maxHeightRatio = 0.32` 由 `UIScreen.main.bounds.height` 换算，未单独做横屏高度校验（spec 平台边界仅 iPhone 竖屏）；标签降级的体验结论由 080 盲测承接。
