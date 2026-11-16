---
id: 081
title: 舱内标注落地与死按钮清理
status: ready-for-agent
stage: M3
blocked_by: []
---

## 背景

077 遗留、079 漏检的两个无动作控件（`.tiangongHold`「保持」、`.tiangongInteriorLabels`「舱内标注」）
在 2026-11-16 复核中查实：按钮渲染在底部但 `actions.control` 落 `default: break`，点击零副作用。
079-diff 曾把 C5 记为「对齐」，不成立——稿要求的三处标注+引线从未实现
（071 只做了内景几何 `lab-interior` 与剖面卡片一行文案「睡眠区 · 健身区 · 设备机柜 · Ø0.8 m 转移通道」）。

董事长裁决（2026-11-16）：**删按钮+登记差异**。不动 PRD 对接语义，不给待门禁的 080 引入新功能。

## 已完成（删按钮部分，commit 764ee14）

- [x] 删 `ChromeControlID.tiangongHold` / `.tiangongInteriorLabels` 枚举与 `derive` 分支
- [x] 「保持」定性为冗余：`TiangongDocking.judge` 进容差后自动累计 `holding` 至 1s 判 `docked`，无需手动按钮
- [x] TDD：2 条新断言先红（`/tmp/spacewalker-081-deadbuttons-red.log`）后绿，全量 390 项 0 失败（`/tmp/spacewalker-081-deadbuttons-green.log`）
- [x] 对抗验证：临时 XCUITest 无头启动剖面/对接两态，断言死按钮不存在、其余控件在位，1 test passed（`/tmp/spacewalker-081-probe.log`）；探针验后删除，`xcodegen generate` 无漂移
- [x] 稿实现同源双向回改：open-design 稿 C4/C5 删按钮、plate-note 与「实现对照」节补记；`079-14-screen-diff.md` C5 降级「部分」、C4 更新；077 票遗留销账
- [x] 截图归档 `docs/gates/M3/081-cutaway-no-interior-labels.png`、`081-docking-no-hold.png`

## 出稿记录（2026-11-17）

实现方案已出稿：`docs/design/2026-11-17-interior-labels/proposal.md`。
推荐**常显**（随剖面态自动出现，无开关按钮）+ 复用 labelLayer 投影机制 + 三真实内景实体锚点；
备选「恢复开关」不推荐（与 081 删死按钮裁决的收敛方向相悖）。
待董事长确认三点：常显 vs 开关、字号 11pt token vs 稿 12pt、实现时机（080 后 vs 插队）。
确认前不动代码。

## 待做（本票剩余范围：舱内标注设计意图 → 实现）

- [ ] 剖面态三处标注（睡眠区 / 健身区 / 设备机柜）+ 1px 引线，只在剖面态出现（稿 C5：字体 12pt）
- [ ] 标注可开关（恢复「舱内标注」控件，这次带真实动作）或常显——方案先出稿确认再动代码
- [ ] VoiceOver 能读出三处分区名（071 验收欠账一并补）
- [ ] 不改变默认视图基线（模式默认关闭约束，PRD v0.11）
- [ ] 几何预算不回归（标注走 SwiftUI overlay，不进 RealityKit 实体数）

## 测试缝

`ChromeState.derive(.tiangong, mode: .cutaway)` 控件断言 + 标注可见性派生断言（沿用 081 已加的 2 条）；
视觉与引线位置用无头截图对照（`SPACEWALKER_TG_CUTAWAY=1`）。

## 备注

- 「回退」（稿 C4）同为设计意图未实现，但不在本票范围；要做另开票。
- 本票不影响 080 门禁：删按钮是缺陷修复，080 取证时需以含 764ee14 的包为准重取两张截图（旧 `080-device-*.png` 里天宫默认态不含这两个控件，不受影响；剖面/对接态未在 080 取证范围内）。
- `status: ready-for-agent` 仅指「舱内标注」实现部分；删按钮部分已实施并附证据，状态流转仍由人确认。