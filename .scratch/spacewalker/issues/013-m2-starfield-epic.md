---
id: 013
title: M2 房间星海（epic）
status: needs-triage
stage: M2
blocked_by: [011]
---

## 背景

M2 的占位 epic。目标是把 A 阶段的单点交互升级为"走动 + 姿态选中"的房间级体验，具体子 ticket 在 M1 门禁通过后拆。

## 覆盖范围

- FR-B-01 星海生成（2000 实例，`MeshInstancesComponent`）
- FR-B-02 视锥选中（仅 20 颗命名星体可选）
- FR-B-03 选中反馈
- FR-B-04 走动与漂移治理
- FR-B-05 LOD
- FR-B-06 性能预算

## 出口标准

- O2-KR1：30 次预设目标，选中成功率 ≥ 90%，误选 ≤ 2 次。
- O2-KR2：触摸/姿态切换后状态保持。
- O2-KR3：2000 实例平均帧率 ≥ 55fps。
- 漂移 ≤ 20cm（NFR-10）。

## 备注

- 拆票前置：M1 门禁通过、M1 的性能基线已归档。
- 不在本 epic 内做 C 阶段内容。
