---
id: 083
title: 今夜对齐态在 chrome 上不可见（tonight mode 不可达）
status: ready-for-agent
stage: M3.1
blocked_by: []
---

## 现象（2026-11-17，082 截图采集时查实）

模拟器无头启动 `MODE=sky ALIGN=1 LAT=39.9 LON=116.4`，session.log 证实
`sky.align simulated location=39.900,116.400`（observer.stage=.ready，对齐已生效），
但截图上：状态条仍「姿态跟随 · 转动手机环顾」、主操作仍「找星」、上下文控件仍「图层/今夜/姿态」，
「今夜」控件无选中态。用户点「今夜」按钮后同样无任何 chrome 反馈。

## 本质（代码证据，非猜测）

1. `SkyView.syncMode()`（SkyView.swift:247）只派生 finder/asterisms/history/card/normal，
   **从不产出 `.tonight`**；全仓 `setMode(.tonight)` 零调用。
2. `ChromeState.derive` 的 `.tonight` 分支（状态条「对齐今夜此刻的真实天空」、主操作「对齐」、
   控件「定位/城市/重置」，ChromeState.swift:182/226/278）全部为**死代码**。
3. `SkyObserver.statusText`（「今夜此刻 · …」系列文案）全仓零消费——纯死属性。
4. `ChromeControl.isSelected` 对「今夜」恒 false，对齐开关状态不上 chrome。

即：079-diff A5 记「实现保留既有对齐开关与时间滑杆」只对了功能半边，
稿 A5 的「今夜态 chrome」（状态条/主操作/控件组）从未接线。与 081 死按钮同族：
**derive 有分支、运行时不到达**。079 对照谓词只查结构文案不查可达性，故漏检（见 findings 2026-11-16）。

## 影响

- 用户无法从界面判断「今夜对齐」是否已开启（功能生效但零反馈）——可用性问题，非崩溃。
- 上架截图第 3 张（今夜对齐卖点）现版拍不出差异，082 暂用默认态顶位。
- 079-diff A5 的「部分」处置需补记本缺口。

## 修复方向（先出稿确认再动代码，wb-design-apply A 路径）

- 方案一（贴稿）：对齐开启且无卡片/面板时 syncMode 产出 `.tonight`，激活既有 derive 分支；
  需处理与 `.card` 的优先级（选中星时仍 card）与「对齐」主操作语义（再点=关闭对齐？稿未定义，需裁决）。
- 方案二（最小）：不动 mode，只给「今夜」控件接 `isSelected = observer.isOn`，
  状态条 detail 在对齐时换「今夜此刻 · 时间已对齐」（消费 statusText 或简化文案）。
- 两案都不动 PRD 对齐语义；方案一改动面大、需回改稿 A5 交互注释，方案二 30 行内。
- 测试缝：`ChromeState.derive` tonight 分支断言（现有）+ syncMode 派生断言（新增）+
  无头截图对照（ALIGN=1 前后状态条差异）。

## 裁决（2026-11-17，董事长批「按拟定执行」）

**采用方案二（最小反馈）**：「今夜」控件接 `isSelected = observer.isOn`，
状态条 detail 对齐时换「今夜此刻 · 时间已对齐」（消费 statusText 或简化文案）。
不动 mode 派生、不新增 derive 分支。方案一（.tonight 模式页）不采用——
城市/时间滑杆本是设计意图未实现，toggle 语义稿未定义。

**实施时机：080 人工门禁签字后**（不插队）。触发后 TDD：
isSelected + statusText 断言 → 实现 → 重拍截图第 3 张 → 079-diff A5 更新。

## 边界

不在 080 门禁取证范围内新增功能；当前仅登记，082 截图第 3 张以默认态顶位并注明。