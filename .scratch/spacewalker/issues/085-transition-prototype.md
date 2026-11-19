---
id: 085
title: 层间转场原型（探针，不碰生产代码）
status: done
stage: M4
blocked_by: []
---

## 背景

全案唯一真正未知：星图由设备姿态驱动（`SkySession.followsAttitude` 默认 true），太阳系是自由机位（`OrbitRig` yaw/pitch/distance 4–18）。ADR-0006 D3 已裁定「下钻即切手动」，于是转场退化为机位补间——但**画面是否可信**只能在屏幕上回答，不能在文档里回答。

本票只产出结论，不产出实现：原型代码可丢弃，生产代码零改动。

## 验收标准

- 从星图边界机位到太阳系起始机位的 450ms 转场可连续播放，可正反各 3 次。
- 三条判据（ADR-0006，任一不成立即判失败）：
  1. 无超过 1 帧的黑帧/白帧；
  2. 1 名未看过产品的人，8 秒内能说出「退远了，但还在同一片天空」；
  3. 尺子读数单调、无回跳。
- 结论写成 `docs/findings/2026-11-XX-scale-transition-prototype.md`，附录屏与逐帧截图。
- 生产 `Sources/` 零改动（原型放 `.scratch/prototype/` 或独立 target）。

## 测试缝

无单测。手工脚本 + 模拟器录屏；姿态用 `LaunchMode` 的 `SPACEWALKER_*` mock 参数驱动。

## 备注

- 失败不是坏消息：096 已允许退化为硬切 + 淡化，本条结论决定 096 只做导航还是连转场一起做。
- 依赖：无。可与 086/087 并行。

## 执行记录（2026-11-19）

- 结论与证据：`docs/findings/2026-11-19-scale-transition-prototype.md`
- 判据 1（无 >1 帧黑/白帧）过：0.45s 与 2s 两版录屏、六段窗口逐帧亮度核验，黑帧 0 白帧 0。
- 判据 3（尺子单调）过：六段读数 0 违例（对数插值 + smoothstep）。
- 判据 2（外部人 8 秒认知）待人审：录屏 `.scratch/prototype/transition/evidence/roundtrips3.mp4`。
- 096 按完整转场做；若人审否决再退化硬切 + 淡化。
- 生产 Sources/ 零改动；新增独立 target TransitionProbe（project.yml +42 行）与原型源码。
