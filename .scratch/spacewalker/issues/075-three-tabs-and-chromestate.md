---
id: 075
title: 三 tab 导航与 ChromeState 地基
status: ready-for-agent
stage: M3
blocked_by: []
---

## 背景

把「用户在三个房间之间怎么走」变成产品里看得见、代码里可断言的一件事：底部出现 3 个带文字的一级入口（星图 / 太阳系 / 天宫一号），任意模块一次点击互达；首次打开落在星图。同时在 `AppState` 上建立本次重构唯一的结构真相 `ChromeState`（本票先落最小字段），让后面每一票都能用 `TestStore` 断言界面结构，而不是靠截图。

父 spec：074。

## 验收标准

- [ ] 一级导航恰好 3 项，都带文字，当前项有明确指示（用 v1.1 稿 token）
- [ ] 从任意模块到任意模块 ≤1 次点击；天宫不再只能从太阳系进入
- [ ] 默认落地 `route == .sky`（`LaunchMode.initialRoute` 与 `AppState` 初始值同源）
- [ ] `ChromeState` 为 Equatable / Sendable 值类型，含 route、tab 项、选中指示；由纯函数 `derive` 计算，reducer 在 `.route` 时统一重算
- [ ] `TestStore` 断言：3 个 tab 的文字与选中态、默认 `.sky`、切换后选中项同步
- [ ] 既有 358 项测试全绿，零回归
- [ ] 生产代码零注释；新增文件后跑 `xcodegen generate`

## 测试缝

`ChromeState` + `makeAppReducer()`，复用 `TestStore.send/assert`；先例 `AppReducerTests`、`SolarSystemReducerTests`。只断言外部可观察状态，不断言 View 层级或像素。

## 备注

- 视觉基准：v1.1 稿 14 屏，底部一级 tab 区 y 784–840。
- 本票是地基，不改三个主视图的顶部状态卡与底部图标栏内容；那些属于 077。
- 每步完成后提交，commit message 引用 075；精确 add，不带入无关漂移。
