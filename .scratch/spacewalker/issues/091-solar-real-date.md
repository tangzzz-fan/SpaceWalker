---
id: 091
title: 太阳系改真实日期位置 + 光行时
status: ready-for-agent
stage: M4
blocked_by: [086, 088]
---

## 背景

行星位置来自 `SolarSystemModel.swift` 的 `startPhase`（8 处硬编码），与「今天」无关。用户看到的是一张永远一样的太阳系。

## 验收标准

- 行星位置由 086 给出，误差 ≤10′（NFR-11）；时间轴 0 点 = 当天 00:00 UTC+8，可前后拖 ±1 年。
- 信息卡增加「光从太阳到这里需要 X」；数值由同一星历算出，不手写。
- 原 A 阶段拾取往返 9/9 不回归；教学比例与操纵方式不变。
- 时间轴拖到极端位置不跳变、不越界。

## 测试缝

`Tests/SolarEphemerisTests.swift` + 既有 `SolarSystemTests` 全绿。

## 备注

- 依赖 086/088；092/093 在它之上做。
