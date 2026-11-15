---
id: 077
title: 底部三段布局与只读状态条
status: ready-for-agent
stage: M3
blocked_by: [075, 076]
---

## 背景

把三个模块长得一模一样的「小字墙 + 一排无文字图标」换成统一骨架：顶部 44pt 只读状态条（模块名 + 一句状态 + 「…」），底部自上而下唯一主操作条 → ≤3 个带文字上下文控件 → 3 个 tab。主操作落在屏幕下 40%，单手可达。

父 spec：074。

## 验收标准

- [x] 三个主视图同为 44pt 只读状态条，两行以内，右侧只有「…」
- [x] 底部三段：主操作（1 个暖金实心，y 680–740）→ 上下文控件（≤3，都带文字，740–784）→ 3 个 tab（784–840）
- [x] 主操作随模块变化（星图「找星」/ 太阳系「聚焦」/ 天宫「开始拆解」等），不重复出现在状态条或卡片里
- [x] `ChromeState.primaryAction / contextControls / statusLine` 由 `derive` 计算；reducer 通道断言唯一性、≤3、都带文字、归属底部
- [x] A1 / B1 / C1 截图与 v1.1 稿逐屏对照，差异回改稿或回改实现
- [x] 358 项既有测试全绿；60fps 不回归（真机复测由 080 承接）

## 测试缝

`ChromeState` 派生 + reducer 断言通道；视觉与布局用截图对照，不新增 XCUITest 断言。

## 备注

- 父票 075、076。本票开始就按 v1.1 token 写，不攒到 079 返工。
- 稿与实现同源：任何布局调整都要回改 `xingcha-ui-v1` 的 v1.1 稿。
- 每步完成后提交，commit message 引用 077。

## 实施证据（agent 自验，状态流转仍由人确认）

- 红灯 `/tmp/spacewalker-077-red.log`：`ChromeStateTests.swift` 引用尚不存在的 `ChromeState.primaryAction / statusLine / contextControls / ChromeMode / ChromeSelection`，编译失败 10 处。
- 绿灯 `/tmp/spacewalker-077-final.log`：`xcodebuild test -scheme SpaceWalker -destination 'platform=iOS Simulator,name=iPhone 18 Pro'` → **377 项、0 失败**（076 的 369 + 8 条 `ChromeStateTests`）。
- 点按对抗验证 `/tmp/spacewalker-077-tap-probe.log`：临时 XCUITest（`SkyCheck` scheme，**1 test passed / 17.1s**，验证后已删除并 `xcodegen generate` 确认无工程漂移）依次点「暂停」→状态条写回「已暂停」、切 tab「天宫一号」→主操作「开始拆解」、点「开始拆解」→主操作「装回」、切 tab「星图」→主操作「找星」。证明 registry 接线、mode 同步与 reducer 派生在运行时真的工作，不只是编译过。
- 三屏证据 `docs/gates/M3/077-A1-sky.png` / `077-B1-solar.png` / `077-C1-tiangong.png`：44pt 只读状态条（模块名 + 一句状态 + 「…」）、暖金唯一主操作、≤3 个带文字上下文控件、3 个 tab；太阳系状态条按稿写「运行中 · 第 N 天」。
- 稿与实现同源：v1.1 稿 `index.html` 中 5 处「姿态跟随 · 今夜已对齐」回改为「姿态跟随 · 转动手机环顾」（实现不谎称已对齐今夜）；C1「目标飞行器 · 1:20 展示」由 `TiangongScale.ratio` 计算，与稿一致。
- 实现引入 `ChromeActionRegistry`（显式传参，不用 `@Environment`，第一次尝试用 environment 导致启动崩溃，已改）；主操作与上下文控件的行为由各模块就近注册，`ChromeState` 只决定结构与文案。

## 本票遗留（转 079 对照清单）

- 稿 C1 的三段任务条、A3/A4/A5 的内嵌搜索/星官/今夜页、C4 对接 HUD 的四类失败判据，实现仍是既有 sheet / 卡片，不是稿里的内嵌屏；需在 14 屏对照里逐条定性。
- `.tiangongHold`（保持）、`.tiangongInteriorLabels`（舱内标注）目前无对应 session 动作，按钮存在但点击无副作用；079 需回改稿或补行为。
- 60fps 真机复测由 080 人工门禁承接，本票不宣告通过。
