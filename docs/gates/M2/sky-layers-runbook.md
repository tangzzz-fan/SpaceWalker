# 星图全图层真机验收（runbook）

| 项 | 内容 |
|---|---|
| 目的 | 量「五层图形全开」时的真机帧率、卡顿、热状态与可读性 |
| 关联 | issue 040 之后的下一步；`docs/gates/M2/sky-selection-2026-11-07.md` 只覆盖了姿态与拾取，不含内容层 |
| 执行 | 人工（agent 不判定真机体验） |
| 耗时 | 约 5 分钟 |
| 现状 | 帧率部分已由 agent 用 `devicectl` 自驱动跑完，见 `sky-layers-2026-11-07.md`；本文件保留为人工复核与夜间户外补充用 |

## 1. 为什么必须真机跑

底座（星点 + 星座线）在 iPhone 16 Pro 上是 66–67Hz，但那是 145 项单测时代的场景。现在同一片天上多了：

| 层 | 段数 / 面数 |
|---|---|
| 星座连线 | 138 段 |
| 星座轮廓 | 15 个填充面 + 15 圈描边 |
| 星官 | 814 段 |
| 星群 | 98 段（虚线） |

模拟器（iPhone 18 Pro / Apple Silicon）恒 60fps，这个数字不作数：它不能代表 A17/A18 的 GPU 预算，也量不到发热降频。

## 2. 准备

```bash
cd /Users/tango/Developments/SpaceWalker
tools/device.sh run --build
```

`tools/device.sh` 会自动挑「有线连接的那台真机」，装包并按全图层启动。手工等价命令：

```bash
xcodebuild -project SpaceWalker.xcodeproj -scheme SpaceWalker \
  -destination 'generic/platform=iOS' -derivedDataPath build build
xcrun devicectl device install app --device <UDID> \
  build/Build/Products/Debug-iphoneos/SpaceWalker.app
```

## 3. 启动（五层全开 + 帧率探针）

```bash
xcrun devicectl device process launch --device <UDID> \
  --environment-variables '{"SPACEWALKER_MODE":"sky","SPACEWALKER_LAYERS":"1","SPACEWALKER_FPS":"1"}' \
  com.tango.spacewalker
```

- `SPACEWALKER_LAYERS=1`：连线 + 轮廓 + 星官 + 星群一次全开。
- `SPACEWALKER_FPS=1`：屏幕右上角出现 `58fps · min 41 · 卡顿 2`，同时每 5 秒往 `session.log` 写一行 `sky.perf`。

## 4. 五分钟脚本

| 段 | 时长 | 动作 | 看什么 |
|---|---|---|---|
| A | 30s | 平举不动，对准任意天区 | 读数是否稳在 60；`min` 是不是被首帧拖低 |
| B | 60s | 慢慢转一整圈（横扫 360°，含天顶与地平） | 轮廓色块在真实夜空下还能不能看出层次；读数掉多少 |
| C | 30s | 快速甩动 3 次，模拟「找不到星」的扫视 | 卡顿数是否跳；甩动时星空是否撕裂 |
| D | 3 次 | 对准任一颗亮星停留 0.6s 出星卡 | 停留判定在真机上是否仍准（底座已验证，这里只做回归） |
| E | 30s | 进「星座」菜单关掉星官与星群，只留连线 | 对照组：读数回升多少，就知道哪层最贵 |

> 建议在户外或暗环境跑，B 段才看得出轮廓色块的真实可读性；室内白墙上对比度完全不同。

## 5. 取回日志

`SessionLog` 除了写文件，也会以 `notice` 级打到统一日志（subsystem `com.tango.spacewalker`，category `filelog`），所以两种取法都行。

**边跑边看（推荐，能同时看画面和读数）**：打开 Console.app，左侧选中 iPhone，右上搜索 `subsystem:com.tango.spacewalker`，等级选 Include Info/Debug。

**事后取文件**：

```bash
xcrun devicectl device copy from --device <UDID> \
  --domain-type appDataContainer --domain-identifier com.tango.spacewalker \
  --source Documents/session.log --destination ./session-device.log

grep -E "sky.budget|sky.perf" ./session-device.log
```

期望看到（模拟器基线，仅示范格式）：

```
sky.budget entities=16 meshes=12 constellation=138 asterism=814 pattern=98
sky.perf avg=60.0 min=59.8 hitch=0.0% thermal=nominal layers=line+outline+asterism+pattern
```

`entities=16` 是个好消息也是条线索：整个天球只有 16 个实体、12 个 mesh，说明掉帧（如果有）不会来自节点数量，只可能来自像素填充率——也就是轮廓色块与 814 段星官的覆盖面积。

**控制台里还会有这些，都不是我们的问题**（已逐条核对）：

| 输出 | 来源 | 要不要管 |
|---|---|---|
| `asset string 'engine:throttleGhosted.rematerial' parse failed` | RealityKit 内部降频材质 | 不用，删代码也不消失 |
| `EnvironmentResource with no skybox texture is no longer supported` | RealityKit 默认环境（iOS 27 弃用提示） | 不用，试过移除 `content.environment` 仍然报警 |
| `VideoLightSpillGenerator ... YCBCR8_420_2P` | 相机纹理预热，星图是虚拟相机 | 不用，预期 |
| `cannot add handler to 0 from 0 - dropping` ×N | xpc/analytics | 不用 |
| `CoreMotion.plist ... Operation not permitted` | 沙盒读系统偏好 | 不用，姿态数据正常 |
| `AX Safe category ...`、`PointerUI ...` | 辅助功能 / 指针服务 | 不用 |

## 6. 判读

| 指标 | 过 | 不过时的改法 |
|---|---|---|
| avg fps | ≥ 55（B 段） | 先把轮廓填充从半透明面改为仅描边；或把星官 814 段按星等分档、聚焦时才画 |
| min fps | ≥ 40 | 同上；另查首帧是否拖低（A 段就能看出） |
| hitch | < 2% | 查是否有每帧重建 mesh 的路径（目前高亮才重建，理论上不会） |
| thermal | 5 分钟内不升到 `serious` | 降填充面优先；其次把 67Hz 姿态更新降为 30Hz 平滑输出 |
| 可读性 | 能分清「连线 / 轮廓 / 星官 / 星群」四种线 | 调四层的亮度与管径，而不是加图例 |

任何一项不过，先记原始日志行，再改；不要凭观感先动参数。

## 7. 已知边界

- 无绝对北：航向是陀螺仪积分，分钟级漂移，本票不处理（FR-B-05）。
- 轮廓色块是 `UnlitMaterial` 深蓝填充，室内白墙背景下会显得「糊」；这是设计取舍，不是 bug。
- 探针本身每 5 秒写一行日志，开销可忽略；但 `SPACEWALKER_FPS=1` 会多一次 SwiftUI 每秒刷新，正式包不要带。
