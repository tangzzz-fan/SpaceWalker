# 085 转场原型结论：机位补间 + 双层淡化可信，096 按完整转场做

- 日期：2026-11-19
- 票：`.scratch/spacewalker/issues/085-transition-prototype.md`
- 裁定依据：ADR-0006 D3/D13
- 原型代码：`.scratch/prototype/transition/`（独立 target `TransitionProbe`，生产 `Sources/` 零改动）
- 取证：`.scratch/prototype/transition/evidence/`（0.45s 录屏 `roundtrips3.mp4`、
  关键帧 `keyframes/*.png`、逐帧亮度 `keyframes/luminance-*.csv`、`session.log` 全量与摘录；
  中间抽帧 ~3GB 已清理，可用 `extract_frames.swift` 从录屏复现）

## 结论（先说答案）

**三条判据：1 过、3 过、2 待人审。096 按「完整转场」做，不退化硬切。**
判据 2 需要 1 名未看过产品的人看录屏后 8 秒内作答，AI 不能自任外部评审；
录屏已备好（`evidence/roundtrips3.mp4`，0.45s 生产时长 × 正反 3 次），董事长可直接转发。
若人审否决，096 的转场层退化为硬切 + 淡化，阶梯导航不受影响（票内已预留该分支）。

## 原型是什么

- 单 RealityView 承载星图（`SkyScene`，手动机位 `SkyRig()`，FOV 60→55 补间），
  第二个 RealityView 承载太阳系（`SolarSystemScene`，机位从 `ScaleLevel.sky.handoffRig`
  yaw 0/pitch 0.52/distance 18 补间到 `ScaleLevel.solar.handoffRig` 默认机位），
  两层共用同一张银河 skybox（`SpaceEnvironment.load()`），上层 `.opacity(p)` 淡化。
- 进度 p 用 smoothstep 缓动，时长 0.45s（`PROBE_SECONDS` 可拉长供取证）。
- 尺子读数走 088 的 `ScaleRuler.readingMeters(from:.sky,to:.solar,progress:)`，
  对数插值 1000 光年 ↔ 1 AU，每 4ms 采样入日志。
- 自动正反各 3 次；`FrameRateBox` 挂 `SceneEvents.Update` 记帧间隔。

## 判据逐条证据

### 1. 无超过 1 帧黑帧/白帧 —— 过

- 0.45s 生产时长录屏（`roundtrips3.mp4`，60fps 抽帧 906 帧）：
  六段转场窗口（按 session.log 时间戳对齐）逐帧亮度 min 3.5 / max 5.7（深空底本身 ≈4–6），
  **黑帧 0、白帧 0**。全片唯一白段是模拟器冷启动白屏（frame 79–262，app 首帧之前），
  与转场无关——生产 app 有 LaunchScreen 底色，不存在该窗口。
- 2s 拉长版（`roundtrips2.mp4`，30fps 抽帧 968 帧）同样六段窗口黑帧 0 白帧 0。
- 判定阈值：meanLuma < 2 记黑帧、whiteRatio > 0.5 记白帧（`extract_frames.swift`，
  64×128 降采样亮度统计，CSV 在 `evidence/frames*/luminance.csv`）。

### 2. 外部人 8 秒内说出「退远了，但还在同一片天空」—— 待人审

- 画面事实（关键帧 `evidence/keyframes/2s-descend-mid.png`、`2s-ascend-solar.png`、`045-ascend-mid.png`）：
  转场中段星空与太阳系同框，星座连线未断，行星轨道从星点间浮出；
  两层共用同一银河底图，背景星点连续。
- 这是「画面是否可信」的唯一不可机判项。录屏 `roundtrips3.mp4` 前 8 秒即第一次下钻+上行，
  可直接发给未看过产品的人。**本条不自行判过。**

### 3. 尺子读数单调、无回跳 —— 过

- 0.45s 运行六段读数（session.log `probe.readings.*`，按 summary n 精确切分）：
  descend.1 n=75 / ascend.1 n=84 / descend.2 n=84 / ascend.2 n=76 / descend.3 n=87 / ascend.3 n=87，
  **单调性违例全部为 0**；首末值精确落在 9.4607e18 m（1000 光年）与 1.496e12 m（1 AU）。
- 2s 运行六段（n=342–394）同样 0 违例。
- 对数插值天然单调，smoothstep 缓动不改变单调性——这条在数学上就成立，实测是复核。

## 帧率

- 0.45s 生产时长：avg 60.0 / min 52.2 / hitches 0（`probe.fps`）。
- 2s 拉长版：avg 58.1 / min 27.5 / hitches 2（双 RealityView 同屏 + 每帧星历重算，
  拉长版把每帧 apply 的开销摊得更长；生产 0.45s 窗口内无 hitch）。
- 注意：原型是双 RealityView 叠加，096 实现若改为单 view 双 root 切换，开销只会更低。

## 对 096 的直接输入

1. 交接机位用 088 常量表 `handoffRig`，不要另发明数值。
2. 转场 = 星图 FOV 60→55 + 太阳系机位 handoff→默认 + 上层 opacity 0→1，三者同 p 驱动，
   smoothstep，0.45s（≤450ms 验收线内）。
3. 星图下钻瞬间 `setFollowsAttitude(false)`（D3），上行恢复并提示一次。
4. 尺子读数与转场共用同一个 p，杜绝「画面到了读数没到」。
5. 银河底图两层共用是「同一片天空」观感的关键，096 不得给星图换底。

## 代价与如果重来

- 本轮探针共 3 次录屏：第一次 `--console-pty` 启动方式在 22s 窗口结束时进程被挂起
  （ascend.3 卡住、fps/done 未落日志），且录屏里混入冷启动白屏段，差点把白屏误记到转场头上。
  第二次改普通 `launch` + 跑完主动 `terminate`，并用 session.log 时间戳把白屏段与转场窗口
  严格分离后才敢下判据 1 的结论。
- 教训：**录屏取证必须先对齐 app 时间线与视频时间线**（冷启动白屏、启动尖峰都不属于被测窗口）；
  `--console-pty` 不适合长时无人值守运行。
- 抽帧工具用 Swift + AVFoundation 现写（本机无 ffmpeg/cv2），`extract_frames.swift` 可复用。