# 041 星图全图层的真机负载：先装好仪表，再让人跑

## 一、缺口在哪

真机证据只有一份：`docs/gates/M2/sky-selection-2026-11-07.md`，量的是姿态跟随（67Hz 稳）与准星往返（288/288）。那时候场景里只有星点 + 星座连线。

此后加的内容层，一个都没上过真机：

| 层 | 量 |
|---|---|
| 星座连线 | 138 段 |
| 星座轮廓 | 15 个填充面 + 15 圈描边 |
| 星官 | 814 段 |
| 星群 | 98 段 |

模拟器的 60fps 不作数——它既不代表 A17/A18 的 GPU 预算，也量不到降频。

## 二、这一轮加的三件仪表

| 件 | 作用 | 落点 |
|---|---|---|
| `SPACEWALKER_LAYERS=1` | 五层一次全开，排除人工漏勾 | `SkyView.load()` |
| `SPACEWALKER_FPS=1` | 右上角 `58fps · min 41 · 卡顿 2` + 每 5 秒一行 `sky.perf` | `SkyPerformanceProbe` |
| `sky.budget` | 首帧后记一次实体数、mesh 数、各层段数 | `SkyScene.budget()` |

**帧间隔为什么取 `SceneEvents.Update`**：它每帧触发一次，显卡跟不上时触发频率跟着掉，是渲染负载的可用代理。`CADisplayLink` 不行——它按屏幕刷新率回调，GPU 掉帧时 delta 仍然是 16.7ms，看不出问题。

复用已有的 `FrameRateSampler`（原本给 AR 会话量漂移用），只把 `FrameRateBox` 从 private 放开到模块内——两边都要在渲染线程写、主线程读。

## 三、模拟器基线（只作格式与量级参考）

```
sky.budget entities=16 meshes=12 constellation=138 asterism=814 pattern=98
sky.perf avg=60.0 min=59.8 hitch=0.0% thermal=nominal layers=line+outline+asterism+pattern
```

`entities=16` 是个有用的结论：整个天球只有 16 个实体、12 个 mesh。**如果真机掉帧，不会来自节点数量**，只可能来自像素填充率（轮廓色块 + 814 段星官的覆盖面积）。这条判断决定了不过时该改哪里。

## 四、待人工执行

跑 `docs/gates/M2/sky-layers-runbook.md` 的五分钟脚本，回填：

| 指标 | 判定线 | 实测 |
|---|---|---|
| avg fps（B 段横扫） | ≥ 55 | 待填 |
| min fps | ≥ 40 | 待填 |
| hitch | < 2% | 待填 |
| thermal（5 分钟） | 不到 `serious` | 待填 |
| 可读性 | 四层能分清 | 待填 |
| 关星官+星群对照（E 段） | 回升幅度 | 待填 |

agent 不判定真机体验，这一栏只由人填。

## 五、顺带补的测试

5 项，补齐 `FrameRateSampler` 一直没有的数学测试（均值/最低/卡顿比/窗口裁剪/非正 delta），以及两个新开关的解析。273 项 0 失败。
