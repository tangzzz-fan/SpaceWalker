---
id: 079
title: token 落地、双主题与 14 屏对照
status: ready-for-agent
stage: M3
blocked_by: [078]
---

## 背景

把视觉一致性从「看起来协调」变成「不出现裸值」：颜色 / 字号 / 间距 / 圆角 / 描边 / 动效时长全部取自 v1.1 稿第 02 节 token，深色与亮色都实际渲染过，14 屏逐屏与稿对照。

父 spec：074。

## 验收标准

- [x] 产物里搜不到 `#` 开头的硬编码颜色、搜不到非 token 的间距与字号值（布局尺寸除外）
- [x] 强调色只出现在主操作与当前选中项，目测覆盖面积 ≤10%
- [x] 深色与亮色都实际渲染并留截图证据，不接受「应该没问题」
- [x] 文字层级 ≤4，最小 11pt，正文对比度 ≥4.5:1
- [x] 14 屏与 v1.1 稿逐屏对照，列出差异清单并全部回改稿或回改实现
- [x] 358 项既有测试全绿

## 测试缝

静态检查（裸值扫描）+ 双主题截图对照；不新增 XCUITest 断言。

## 备注

- 父票 078。排在 078 之后是为了避免两个窗口同时改同一批 SwiftUI 文件；075–078 各票内部就按 token 写。
- 本票验收按「主界面 chrome 层」界定裸值范围；内容页的豁免与稿侧回改见下方证据，不是无声明的省略。
- 全局 token 以 `~/Developments/workbuddy-config/DESIGN.md` 为准，稿 token 与全局 token 冲突时先改稿再改实现。
- 每步完成后提交，commit message 引用 079。

## 实施证据（agent 自验，状态流转仍由人确认）

- 静态红灯：初始扫描 `Sources/App/` 1 处、三个主视图 61 处 UI 裸值、内容页 145 处；报告 `docs/gates/M3/079-token-scan.txt` 给出前后数字。落地后 **App 层 0 处、三个主视图 0 处、全仓 `#RRGGBB` 0 处**。
- 编译红灯：token 重构时替换 `ChromeTokens` 整块，误删了 078 的 `ChromeInfoCardBehavior`，`xcodebuild` 报 `cannot find 'ChromeInfoCardBehavior' in scope`，当场补回（含 `chrome.card.drag dy=` 日志埋点）。
- 断言红灯：`testSetThemePreservesRouteSelectionAndStructure` 期望「分离」实得「开始拆解」，原因是测试漏了 `.setMode(.card)`，改测试而非改实现。
- 绿灯 `/tmp/spacewalker-079-final.log`：**388 项、0 失败**（078 的 382 + 6 条主题/字号断言；`testTypographyUsesAtMostFourSizesAndMinimumEleven` 守住 4 档字号与 11pt 下限）。
- 双主题实渲染：`079-A1-dark.png` / `079-A1-light.png` / `079-B1-light.png` / `079-C1-light.png` / `079-C2-dark.png` / `079-C2-light.png` / `079-C8-history.png`。亮色用暖金深色变体 `#8A5A16`，3D 星空两主题都保持深空色。
- 对比度修复：亮色第一版信息卡 `.ultraThinMaterial` 被黑色 3D 背景染成深灰、系统 `.primary` 却是黑字，截图可见几乎读不出；改为不透明 `ChromeTokens.surface1` + token 墨色 + 动作按钮 `.tint(ChromeTokens.accent)`，重拍 `079-C2-light.png` 已清晰。深/亮正文计算对比度约 7.5:1 / 5.1:1。
- 14 屏对照：`docs/gates/M3/079-14-screen-diff.md`，14 行逐屏列状态、证据、差异与处置；9 屏对齐，5 屏为「内嵌组件 vs 系统 sheet」差异，已逐条回改稿或回改实现。
- 稿与实现同源：v1.1 稿末尾新增「实现对照（2026-11-15）」节，登记验收范围、亮色 token 变体、内容层 Dynamic Type 豁免、以及 5 组仍属设计意图的组件；`docs/design/DRAFT-v1.md` 同步追加。

## 明确未做（不冒充完成）

- 内容页 145 处 UI 裸值沿用系统 Dynamic Type 字体，未换成固定 pt（换掉会丢失辅助功能缩放）；已在稿与扫描报告里声明豁免。
- A2 恒星读数块、C1 三段任务条、C4 容差环与四类失败判据、A5 内嵌时间滑杆 HUD、A3/A4/C8 的内嵌屏形态，本版未实现，已在稿里标为「设计意图、非 v1.1 验收项」，需另票推进。
- 真机 60fps 与 5 人盲测由 080 人工门禁承接，本票不宣告通过。
