# 081 舱内标注实现方案（出稿待确认，未动代码）

> 2026-11-17 · 票 081 剩余范围。按票内约束「方案先出稿确认再动代码」，本文只定稿设计，实现待董事长点头。
> 实现时机同 083：须 080 人工门禁过后，或董事长明示插队。

## 目标（稿 C5 + 071 验收欠账）

剖面态出现三处标注：**睡眠区 / 健身区 / 设备机柜**，各带 1px 引线指向对应内景几何；
只在剖面态出现；VoiceOver 能读出三处分区名；不改默认视图基线；不进 RealityKit 实体数。

## 推荐方案：常显（随剖面态自动出现/消失，无开关按钮）

| 决策点 | 推荐 | 理由 |
|---|---|---|
| 开关 vs 常显 | **常显** | 稿 C5 原文「三处标注只在剖面态出现」本就是无条件语义；081 刚删掉无动作「舱内标注」死按钮，恢复开关=再造一个 chrome 控件+状态分支，违背删按钮裁决的收敛方向；剖面态本身就是用户显式进入的「看内部」模式，标注是该模式的固有内容 |
| 标注载体 | SwiftUI overlay（复用 `labelLayer` 手法） | `TiangongScene.project()` 投影 + `TimelineView(.periodic 0.1s)` + `Path` 引线 + Capsule 标签，与 062 部件名标签同一套机制，零新增 RealityKit 实体 |
| 锚点 | 三个真实内景实体的世界坐标 | `interior-sleep`(0, 0.030, labOffset−0.060)、`interior-gym`(0, −0.032, labOffset+0.030)、设备机柜取 `interior-rack-0`（+58° 位）——scene 新增 `interiorAnchors()` 按名字查实体投影，几何不动 |
| 可见性派生 | `ChromeState.derive(.tiangong, mode: .cutaway)` 时 `visibleLabels` 追加三条 interior 标签 | 纯函数可测；非剖面态零输出，默认基线不变。选中部件时部件名标签共存（id 不同不冲突） |
| 引线 | 1px `strongHairline`，锚点垂直向上 18pt，标签再上移 12pt | 与 labelLayer 现值一致；三锚点 y 值天然分层（sleep 上 / rack 侧 / gym 下），无需额外避让算法 |
| 字号 | `ChromeTokens.captionSize`（11pt） | 稿写 12pt，但全局 caption token 是 11；沿用 token 保持同源，差异在 079-diff 登记一行（也可董事长裁定新增 12pt token） |
| VoiceOver | 每条标签 `.accessibilityLabel("睡眠区"…)`，overlay 层 `.accessibilityElement(children: .contain)` | 补 071 欠账；`allowsHitTesting(false)` 不影响读屏焦点遍历 |

## 备选：恢复「舱内标注」开关（不推荐）

derive(.cutaway) 恢复控件 + session 增 `interiorLabelsVisible` 状态 + actions.control 真实分支。
代价：+1 chrome 控件、+1 状态字段、+1 动作分支、测试面翻倍；且「关掉标注看什么」没有产品答案——
剖面态不看标注只剩灰色几何块。仅当董事长明确要「可开关」时才走此案。

## 实施清单（确认后执行，TDD）

1. 红：`ChromeStateTests` 加断言——derive(.cutaway) 的 visibleLabels 含三条 interior 标签、
   derive(.normal) 不含；`TiangongTests` 加 interiorAnchors 投影断言（mock content）
2. 绿：ChromeState.labels(for:) 增 mode 参数；TiangongScene.interiorAnchors()；
   TiangongView.labelLayer 渲染 interior 标签（复用现有 ForEach，id 前缀 `interior-`）
3. 对抗：无头 `SPACEWALKER_TG_CUTAWAY=1` 截图，三标注+引线可见、非剖面态截图无标注；
   VoiceOver 用 XCUITest `app.staticTexts["睡眠区"].exists` 断言
4. 回写：079-diff C5「部分」→「对齐」（附新截图）；稿 C5 plate-note 更新；081 票销账
5. 080 影响：新增代码需重取证——若插队则 080 基线再更新；若 080 后做则不影响本轮门禁

## 待董事长确认

- [x] 常显（董事长批「按拟定执行」，2026-11-17 实施）
- [x] 11pt token（差异登记 079-diff C5）
- [x] A8 裁决解除阻塞（2026-11-17 07:57），当日实施完成（06d2234）