# M2 / B 阶段：姿态跟随与准星选中证据（2026-11-07）

| 项 | 内容 |
|---|---|
| 设备 | iPhone 16 Pro（iPhone17,1），iOS 27.0（24A437），app 1.0(1) |
| 关联 | `.scratch/spacewalker/issues/022`、`023`，PRD v0.6 FR-B-02 / FR-B-03 |
| 执行 | 姿态与投影由 agent 用真机日志验证；体验判定由人执行 |

## 1. 姿态跟随修复（FR-B-02）

修复前真机表现：转头方向相反、星空剧烈抖动、不跟随。

根因两项，均为代码缺陷而非调参：

1. **换基错误**：`CMDeviceMotion` 参考系 Z 轴朝上，RealityKit 世界 Y 轴朝上。原实现用 `(x, z, y)` 做分量交换，该矩阵行列式为 −1（反射），导致水平方向镜像；正确换基为 `(x, z, -y)`，等价于绕 X 轴 −90° 的纯旋转。
2. **参数化奇异 + 跨帧抖动**：原实现把四元数拆成 `yaw = atan2(x, -z)` 与 `pitch`，在接近天顶时 `∂yaw/∂θ ≈ 1/cos(pitch)` 发散；且姿态经 30Hz 定时器写入 `@State`，再由 SwiftUI body 触发 `RealityView.update` 写实体，落帧与渲染不同步。

现实现：

- 直接用完整四元数（含 roll）驱动星空根节点，`root.orientation = inverse(deviceToWorld)`。
- 四元数约定不再靠假设：用 `motion.gravity` 做运行时校验，两个候选旋转中取满足 `R·g = (0, -1, 0)` 者。
- 运动回调（`.main`，67Hz）内直接写实体，不经过 SwiftUI 状态；20ms 球面平滑抑制高频噪声。
- 顺手修复拾取用局部坐标投影的隐性缺陷（根节点旋转后点击位置全错）。

真机日志（`Documents/session.log`）：

```
[238ms] sky.catalog stars=2996 elapsedMs=4
[239ms] sky.motion started intervalMs=17
[662ms] sky.motion convention=device->reference
[1228ms] sky.motion rate=67 fwd=0.00,-1.00,-0.04
[37329ms] sky.motion rate=66 fwd=0.59,-0.51,-0.63
[39329ms] sky.motion rate=67 fwd=0.61,-0.36,-0.70
```

- 约定判定只发生一次，全程未翻转。
- 采样率稳定 66–67Hz（设定 17ms）。
- 平举朝下 `fwd=(0,-1,0)` → 抬头右转后 `(0.61,-0.36,-0.70)`，逐秒连续无跳变。
- 人工确认：左右、俯仰均跟手，站定不抖。

## 2. 准星选中（FR-B-03）

- 可选中集：有专名且视星等 ≤ 4.5，共 288 颗；其余 2708 颗仅作背景。
- 命中：准星 44pt（半径 22pt）；先按角距 ≤ 4° 预筛取最近 4 颗，再投影复核像素距离。
- 停留：`DwellSelector` 累计 0.6s 触发；换目标归零；丢失目标按 1.5/s 衰减；触发后须离开目标才可重触发。
- 反馈：准星外圈进度环 + 轻触觉。

投影往返探针 `SPACEWALKER_PICKPROBE=1`，对全部 288 颗执行"把该星旋转到画面中心 → `pickAtCenter` 取回自身"：

| 环境 | 结果 |
|---|---|
| iPhone 18 Pro 模拟器（iOS 27.2） | `sky.pickProbe ok=288/288 axis=201,389 view=402,778` |
| iPhone 16 Pro 真机（iOS 27.0） | `sky.pickProbe ok=288/288` |

`axis` 为相机主轴（世界 (0,0,−50)）的投影点，等于视口中心 (201, 389)，说明投影主点与准星中心共用同一坐标系，判定与视觉无系统偏移。

同日单测：145 项 0 失败，其中新增 `SkyPickerTests` 4 项、`DwellSelectorTests` 5 项、`AttitudeMathTests` 5 项。

## 3. 人工待办（agent 不判定）

30 次预设目标，命中成功率 ≥ 90%、误选 ≤ 2（O2 KR1）。按下表顺序举机对准、停留 0.6s，记录"出卡/错误/未触发"。

| # | 星名 | 星座 | 星等 | 赤经 h | 赤纬 ° |
|---|---|---|---|---|---|
| 1 | Sirius | CMa | -1.44 | 6.753 | -16.7 |
| 2 | Canopus | Car | -0.62 | 6.399 | -52.7 |
| 3 | Arcturus | Boo | -0.05 | 14.261 | 19.2 |
| 4 | Rigil Kentaurus | Cen | -0.01 | 14.661 | -60.8 |
| 5 | Vega | Lyr | 0.03 | 18.616 | 38.8 |
| 6 | Capella | Aur | 0.08 | 5.278 | 46.0 |
| 7 | Rigel | Ori | 0.18 | 5.242 | -8.2 |
| 8 | Procyon | CMi | 0.40 | 7.655 | 5.2 |
| 9 | Achernar | Eri | 0.45 | 1.629 | -57.2 |
| 10 | Betelgeuse | Ori | 0.45 | 5.920 | 7.4 |
| 11 | Hadar | Cen | 0.61 | 14.064 | -60.4 |
| 12 | Altair | Aql | 0.76 | 19.846 | 8.9 |
| 13 | Acrux | Cru | 0.77 | 12.443 | -63.1 |
| 14 | Aldebaran | Tau | 0.87 | 4.599 | 16.5 |
| 15 | Spica | Vir | 0.98 | 13.420 | -11.2 |
| 16 | Antares | Sco | 1.06 | 16.490 | -26.4 |
| 17 | Pollux | Gem | 1.16 | 7.755 | 28.0 |
| 18 | Fomalhaut | PsA | 1.17 | 22.961 | -29.6 |
| 19 | Mimosa | Cru | 1.25 | 12.795 | -59.7 |
| 20 | Deneb | Cyg | 1.25 | 20.691 | 45.3 |
| 21 | Toliman | Cen | 1.35 | 14.660 | -60.8 |
| 22 | Regulus | Leo | 1.36 | 10.139 | 12.0 |
| 23 | Adhara | CMa | 1.50 | 6.977 | -29.0 |
| 24 | Castor | Gem | 1.58 | 7.577 | 31.9 |
| 25 | Gacrux | Cru | 1.59 | 12.519 | -57.1 |
| 26 | Shaula | Sco | 1.62 | 17.560 | -37.1 |
| 27 | Bellatrix | Ori | 1.64 | 5.419 | 6.3 |
| 28 | Elnath | Tau | 1.65 | 5.438 | 28.6 |
| 29 | Miaplacidus | Car | 1.67 | 9.220 | -69.7 |
| 30 | Alnilam | Ori | 1.69 | 5.604 | -1.2 |

注：#21 Toliman 与 #4 Rigil Kentaurus 视位置相差 0.006°，肉眼不可分（半人马座 α 双星），命中较亮者即正确，不计误选。

## 4. 已知边界

- 无绝对北：`.xArbitraryZVertical` 为陀螺仪积分航向，长时间缓慢漂移（分钟级几度），真北对齐属 FR-B-05（P1）。
- RealityView 按安全区布局，星空不铺满刘海与 Home 指示条区域；背景纯黑不可见，如需全屏沉浸另立票。
- PRD Q1「仅 20 颗命名星体可选」与 v0.6 真实星表冲突，当前实现为 288 颗，待决策后统一。
