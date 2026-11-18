---
id: 087
title: 464 颗专名星补距离
status: ready-for-agent
stage: M4
blocked_by: []
---

## 背景

`stars.json` 只有 `ra/dec/mag/ci/name/con/hip`，没有距离；仓库内也没有 HYG 原始 CSV（`tools/build-catalogs.py` 只补 `hip`）。没有距离，「光年 → 米」这条尺子就没有证据。

ADR-0006 D7：先只补 464 颗有专名的星，不重建全表。

## 验收标准

- `Star` 增加可选 `distanceLightYears`；`stars.json` 增加 `dist` 字段（来源写进 json 头）。
- 464 颗中 HYG 缺失的星留空并输出名单（不补 0、不补猜测值）。
- 星表总数与筛选口径不变：2996 / 925 / 464 三个数字不得漂移。
- 生成步骤可重跑，取数命令与 HYG 版本写进脚本头注释。

## 测试缝

`Tests/CatalogTests.swift`：数量、字段存在性、空值分布、距离范围（0.1–10000 光年）合理性。

## 备注

- 需一次性外部取 HYG v4.1；取数不改许可（CC BY-SA 4.0），但重跑后要复核应用内署名。
- 顺带修 `SkyView+Cards.swift:518` 的「1102 颗」（实测 2996）与 `Glise`→`Gliese`，以及 `stars.json` 头里重复的 source 句。
