---
id: 086
title: 离线星历（行星 + 月球）
status: ready-for-agent
stage: M4
blocked_by: []
---

## 背景

星图与太阳系必须看到同一颗行星。现在星图里没有行星，太阳系用硬编码 `startPhase`（`SolarSystemModel.swift` 8 处）。两处若各算一套，位置必然打架。

行星用 JPL "Approximate Positions of the Planets"（Standish）根数 + 变化率；月球用 Meeus 低精度算法。全部纯函数，不依赖 RealityKit。

## 验收标准

- 新增 `Sources/Features/Ephemeris/`，对外只暴露少数接口（行星地心赤经赤纬、月球位置与相位、太阳方向），内部实现不外泄。
- 对 JPL Horizons 固定历元表（≥6 个日期，含 2026-11-18）误差：行星 ≤10′、月球 ≤20′（NFR-11）。
- 纯函数、无全局可变状态、`Sendable`；单测不联网。
- 参考值来源写清查询参数（日期、站点、坐标系、参考系），随 fixture 入库。

## 测试缝

`Tests/EphemerisTests.swift` + `Tests/Fixtures/horizons-*.json`。

## 备注

- 位置**不做**光行时修正；光行时只作为卡片文案（NFR-11）。
- 阈值以像素定：70° FOV / 约 2500 px 屏高下 1 px ≈ 1.7′。
