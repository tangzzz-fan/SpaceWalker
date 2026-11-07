# A 阶段虚拟星系视图 · 证据（2026-11-07）

环境：iOS 27.2 模拟器（iPhone 17）。真机（iPhone 16 Pro / iOS 27.0）待复验。

## 构建与测试

| 项 | 结果 |
|---|---|
| `xcodebuild build`（Simulator） | BUILD SUCCEEDED |
| 单测 | **113 项 0 失败**（新增 27 项：模型 10、reducer 9、几何 4、相机 5、模式 3 — 含既有） |
| 打包资源 | `SpaceWalker.app/galaxy-equirect.jpg` 4.5MB 已入包 |

## 运行时实测

| 项 | 数值 | 来源 |
|---|---|---|
| 天空盒加载 | 868ms（含 4096×2048 JPEG 解码 + 环境资源生成） | `space.environment ready=1 elapsedMs=868` |
| 拾取往返 | **9/9 全部命中自身** | `space.pick.roundtrip ok=9/9 failed=none` |
| 时间轴推进 | 1 天/秒，12 秒后显示「第 12 天」 | 截图 `021-day12.jpg` |
| 中央拾取 | 屏幕中心命中太阳 | `space.pickProbe center=201,389 hit=sun` |

拾取往返的含义：把每个天体的世界坐标投影到屏幕，再拿该屏幕点做拾取，必须返回同一个天体。它同时验证了 `project`、44pt 命中阈值与候选排序三条链路。

## 截图

- `021-solar-system.jpg`：默认视图，8 行星 + 太阳 + 轨道线 + NASA 星空底图。
- `021-day12.jpg`：时间轴推进 12 天后，行星相位变化。

## 已知问题

1. **行星无名称标签**：只有选中后出信息卡，初次进入要靠颜色辨认。候选方案：常驻小标签（需处理遮挡与重叠）或首次引导高亮。
2. **土星夜面偏灰**：PBR 夜面靠 emissive 补光（0.62 系数），土星底色浅导致明暗差小。
3. **天空盒首载偏慢**：868ms 在模拟器上偏慢，真机需复测；若超 1s 考虑降到 2048×1024 或预生成 mipmap。
4. **AR 入口未在模拟器验证**：`SpatialTrackingSession` 在模拟器不可用，需真机点一次「放进房间」。
5. **手势未自动化**：拖动/缩放/点选由人工验证，`simctl` 无法注入触摸。

## 结论

虚拟相机路线成立：不依赖 ARKit、不请求权限、可在模拟器完整走通渲染与拾取。A 阶段不再被平面检测阻塞。真机四项（首帧、帧率、AR 往返、工具栏可用性）待补。

## 第二轮：探针接入与交互补齐（同日）

| 项 | 数值 | 来源 |
|---|---|---|
| 首帧 | **1119ms**（进程启动 → 第一次 `SceneEvents.Update`） | `space.firstFrame ms=1119` |
| 天空盒加载 | 471–585ms | `space.environment ready=1 elapsedMs=471` |
| 帧率 | avg 60.0 / min 48.6–58.9 / hitches 0 | `probe.fps` |
| AR 进出 | `enter daysBefore=4.0` → `exit daysAfter=6.1` | 见下 |

### AR 往返与一处真 bug

用 `SPACEWALKER_AUTOAR=1` 自动执行「进入 AR → 8 秒后退出」，模拟器上没有相机，落在权限解释页（`需要相机才能看见太空`），证明「放进房间」的呈现与返回链路可用。

第一轮日志是 `daysBefore=3.9 daysAfter=14.0`——**AR 面板盖住时太阳系仍在按秒推进**，退出后时间跳了 10 天。已修：`tick()` 在 `showsNativeAR` 为真时直接返回，只更新 `lastTick`。修后同一路径为 `4.0 → 6.1`，只推进了退出后的 2 秒。

这条是真机测不出来的（真机进 AR 后画面被相机占据，更容易被忽略），只有拿日志对时间才看得见。

### 交互补齐

| 项 | 实现 | 证据 |
|---|---|---|
| 选中高亮 | 选中天体缩放 1.3x（`SolarSystemScene.selectedScale`） | 截图 `021-select-jupiter.jpg` |
| 名称标签 | 选中天体上方浮一枚胶囊标签，位置由 `project` 每帧换算 | 同上 |
| 信息卡 | 名称/拉丁名/类型/直径/距日/公转/一句话/比例声明 | 同上 |
| 重置视角 | 控制栏「↺」按钮 → `rig = OrbitRig()`（FR-A-07） | 截图可见 |

### 新增调试开关

- `SPACEWALKER_SELECT=<bodyID>`：预选中一个天体，用于无触摸注入时取「选中态」证据。
- `SPACEWALKER_AUTOAR=1`：自动进出 AR 各一次并记日志。

## 仍未完成（阻塞在真机）

`devicectl` 报 `The tunnel connection failed while the system tried to connect to the device`，iPhone 16 Pro 无法建立调试隧道，以下四项未能取证：

1. 真机首帧 ≤ 3s。
2. 真机帧率 ≥ 55fps。
3. 「放进房间」在**有相机**的真机上进入与退回。
4. 手势（拖动旋转 / 双指缩放 / 点选）与触觉反馈。

## 第三轮：真机（iPhone 16 Pro / iOS 27.0）

设备恢复连接后补测，四项全部有数：

| 项 | 结果 | 日志/证据 |
|---|---|---|
| 首帧 | **965ms**（目标 ≤ 3s） | `space.firstFrame ms=965` |
| 天空盒加载 | 575ms | `space.environment ready=1 elapsedMs=575` |
| 帧率 | avg **60.1** / min 36.4–39.0 / hitches 0 | `probe.fps` |
| 拾取往返 | **9/9** | `space.pick.roundtrip ok=9/9` |
| AR 进入 | `permission.status authorized` → `session.started` → `mode=full` `anchors=3 scene=3 unavailable=0` | `dev-ar.png` 状态条 |
| AR 退出 | `daysBefore=4.0 daysAfter=6.0`（AR 期间时间冻结，退出后只走 2s） | `space.ar.auto exit` |

截图：`021-device-solar-system.jpg`、`021-device-ar-entry.jpg`。

### 两个观察

1. **AR 画面这次是黑的**：状态条显示 `RUNNING / anchors 3 / scene 3 / unavailable 0 / 60fps`，但相机背景全黑。会话与能力都正常，最可能是手机当时平放在桌面上、后摄被遮住。**未定性，需人工复测一次**（举起来对着房间）。
2. ~~**虚拟视图里露出 `漂移 0.0cm`**~~：已修。`SpaceView` 改用 `ProbeSummary.fpsOnlyLine`，不再拼漂移字段。

### 仍未做

- 手势（拖动旋转 / 双指缩放 / 点选）与触觉反馈：需人工。
- 000 的 10 次体验记录：需人工。

## 第四轮：用户试用确认（2026-11-07）

Tang 真机试用后给出「A 阶段的体验，暂时没有问题」。据此把 FR-A-02/03/05/06 的体验侧判为通过。

仍需人工闭环的只剩两项，都不影响「体验成立」这个结论：

- AR 入口那次的画面全黑未定性（后续按「举起手机对着房间」复测一次即可）。
- 手势（拖动旋转 / 双指缩放 / 点选）没有留验收记录。
