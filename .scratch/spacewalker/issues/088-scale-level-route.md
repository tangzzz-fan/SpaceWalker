---
id: 088
title: ScaleLevel 四层与 descend/ascend 路由
status: ready-for-agent
stage: M4
blocked_by: []
---

## 背景

`ContentView.swift:12` 用 `switch store.state.route` 在三个视图间硬切，彼此不共享状态。要先有「层」这个概念，才谈得上阶梯与转场。

## 验收标准

- `ScaleLevel` 四值（sky / solar / earthOrbit / tiangong），每值带代表尺度、尺子文案、交接机位参数——**常量表只有一处**，UI 与测试都读它。
- reducer 支持 `descend(to:)` / `ascend`；非法转换（如 sky → tiangong）被拒且不崩溃。
- 任一层往返重建渲染树（FR-X-03'），返回时保留上一层选中对象。
- 旧 `AppRoute` 要么移除、要么适配到 `ScaleLevel`，全仓无二义。

## 测试缝

`Tests/ScaleLevelTests.swift`：往返不变量、非法转换、尺子文案与常量表同源。

## 备注

- 本票只做路由与状态，不动 UI；导航与转场在 096。
- 089/090/091/094/096 都依赖它。
