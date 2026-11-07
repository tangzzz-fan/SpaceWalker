---
id: 022
title: B 阶段星图（举机观星）
status: ready-for-agent
stage: M2
blocked_by: [021]
---

## 背景

ADR-0004 取消房间追踪。B 阶段改为设备姿态驱动的真实星图：不依赖相机、平面与房间。

## 范围

- 真实星表：HYG v4.1 子集（视星等 ≤ 5.5，保留全部有专名者），J2000 赤道坐标，2996 颗。
- 渲染：按星等分 6 桶、桶内合并为单一网格（球体星点），每桶一个 `UnlitMaterial`。
- 视角：`CMDeviceMotion` 姿态 → 视线 → 星空反向旋转；模拟器回退为拖动。
- 交互：中心准星、轻点选中、信息卡、重置视角。
- 入口：太阳系视图控制栏「星图」按钮；`SPACEWALKER_MODE=sky` 可直达。

## 验收标准

- [x] 加载 2996 颗星（`sky.catalog stars=2996 elapsedMs=4`）。
- [x] 星空渲染：分桶网格、亮暗与颜色可见（模拟器截图）。
- [x] 拖动旋转、重置视角、轻点选中、信息卡。
- [x] 赤道坐标换算与分桶数学有单测（19 项）。
- [x] 真机：姿态跟随连续、俯仰到边界不翻面（修复见 `docs/gates/M2/sky-selection-2026-11-07.md`）。
- [x] 真机：准星停留 0.6s 触发选中（转入 023）。
- [ ] 真机：平均 ≥ 55fps，10 分钟无过热降频。
- [x] 命名星体逐个对准取回自身（`sky.pickProbe ok=288/288`，模拟器与真机各一次）。

## 测试缝

1. `StarField.direction` / `position` / `bucketIndex` / `cubeSize` / `brightness` / `color`（纯函数）。
2. `StarFieldBuilder.sphere` / `merge` / `buckets`（纯数据）。
3. `SkyRig.drag` / `orientation`、`AttitudeMath.solve`、`SkyPicker.nearest`、`DwellSelector.update`（纯函数）。
4. `AppRoute` 与 `LaunchMode.initialRoute`（纯函数）。

## 实现进展（2026-11-07）

- 代码：`Sources/Features/Sky/`（星表、构建器、姿态、拾取、场景、视图）+ `Sources/Resources/stars.json`（216KB）。
- 星表生成：HYG v4.1 原始 32MB CSV → 过滤视星等 ≤ 5.5 且剔除太阳 → 2996 条，字段 `ra/dec/mag/ci/name/con`。
- 姿态：完整四元数 + 重力自校验约定 + 67Hz 直写实体，换基为绕 X 轴 −90° 纯旋转；`(x, z, y)` 曾是反射矩阵，已废弃。
- 模拟器：145 项单测 0 失败；星空渲染正常（截图 `022-sky.jpg`）。
- 未做：星座连线、时间与地点对齐、10 分钟热稳定测试。
