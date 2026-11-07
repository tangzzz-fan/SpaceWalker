---
id: 024
title: B 阶段今夜此刻（FR-B-05）
status: in-progress
stage: M2
blocked_by: [022]
---

## 背景

B 阶段当前是 J2000 赤道坐标按任意朝向摆放：星座形状随会话朝向变化，与"此刻抬头看到的天空"无关；航向也因 `.xArbitraryZVertical` 无绝对北而缓慢漂移。FR-B-05 要求引入恒星时与观测位置，使星图对应今夜此刻。

前置缺陷：`StarField.direction` 把 `(x, z, y)` 做了轴交换，等价于对物理右手系做一次反射（`RA0 × 北极 = -RA6h`，星表给出 `+RA6h`）。单星无感，但一旦对齐真实天空会得到镜像星座，且反射无法用四元数表示。必须先修正。

## 范围

- 修正星表坐标手性：`z = -cos δ sin α`，并加"物理右手系"单测。
- `Astronomy` 纯函数：儒略日、格林尼治恒星时、地方恒星时、赤道→地平（高度/方位）、赤道系到地平系的旋转四元数。
- `SkyObserver`：定位授权、一次航向校准（`CLHeading.trueHeading` + `headingAccuracy` 门限）、会话内保持；状态机 `off / requesting / ready / denied / unavailable`。
- 场景：根节点下设 `field`，`field.orientation = R_y(H − A) × q_eq2horiz`；根节点继续由姿态驱动，两者互不干扰。
- 信息卡：对齐开启时显示所选星的高度角与方位角（用于验收读数）。
- 入口：「今夜此刻」按钮，显示状态文案；未授权时保持赤道坐标且不阻塞主流程。

## 验收标准

- [x] 单测：J2000 历元格林尼治恒星时 280.46°；地方恒星时随经度线性偏移。
- [x] 单测：北极星在地平坐标中的高度角与观测纬度差 ≤ 1°（覆盖 0°/23.5°/39.9°/60°）。
- [x] 单测：赤道系到地平系旋转矩阵正交、行列式 +1；星表基为物理右手系。
- [x] 单测：航向偏移符号——设备真实航向 H 与场景方位 A 之差应使天体落回真实方位。
- [ ] 真机：北京纬度（39.9°）对准北极星，信息卡高度角 38.9–40.9°。
- [ ] 真机：拒绝定位权限后星图仍可用，仅提示「方位未校准」。
- [ ] 真机：转动手机，星座相对位置不随会话朝向改变（星座形状稳定）。

## 实现补充（2026-11-07）

- 室内实测：`trueHeading` 恒为 -1，磁北精度 22°–89°。改为质量门（≤25° 才锁定）+ 状态栏暴露精度，宁可明说"方位未校准"。
- 新增**按星校准**：选中一颗星后卡片出现「以该星校准方位」，用该星的真实方位反解航向偏移
  （`offset = starAzimuth − deviceSceneAzimuth`），避开磁力计；要求该星偏离准星 ≤ 3°，否则按钮禁用并提示把星移到中心。
- 校准后状态栏显示「已按 <星名> 校准方位」，磁力计不再覆盖手动校准。

## 测试缝

1. `Astronomy.julianDay` / `greenwichSiderealDegrees` / `localSiderealDegrees` / `horizontal` / `equatorialToHorizontalRotation`。
2. `StarField.direction` 基向量叉积符号。
3. `SkyAlignment.offset(trueHeading:sceneAzimuth:)`（纯函数）。
