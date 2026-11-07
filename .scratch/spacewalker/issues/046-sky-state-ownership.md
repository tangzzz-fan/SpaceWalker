# 046 状态所有权收口：把 Sky 的运行时状态从 View 里搬出来

- 日期：2026-11-07
- 状态：方案（未动代码）
- 关联：039（轮廓识别与 aimLocked）、043（横屏保尺度与滚转 bug）、045（横屏排版）
- 前置判断：**本轮不做包、不考虑复用**。`public` 税大于边界收益，唯一消费者是自己。

## 一、要解决的是唯一一件事

`SkyView` 1444 行只是症状。病灶是状态所有权分散：

| 现象 | 证据 |
|---|---|
| View 持有 38 个 `@State` | `SkyView.swift:10-47` |
| 朝向有 4 个写入者 | `aim` 664、`setAttitude` 678、`apply(rig:)` 683、`pickRoundtrip` 807 |
| 视场有 3 个数 | `SkyView.zoomBase` 15、`scene.fieldOfView` 15、`scene.baseFieldOfView` 18 |
| 可见性有 2 份真相 | View 的 `showsX` ×4 与 Scene 的 `xxxRequested` ×4 |
| 三套计时器各算各的 | `DwellSelector`（有 `maximumStep`）vs `constellationProgress` 1276 / `patternProgress` 1308（都没有） |

`AppState` 有 6 个切片，唯独没有 `sky`；`ContentView` 的 `switch store.state.route` 会销毁 `SkyView`，所以切走必丢状态。

## 二、定案

| # | 决定 |
|---|---|
| Q1 | `@MainActor @Observable SkySession`，由 `ContentView` 持有并注入；切路由时 `pause()`，场景保留 |
| Q2 | 本轮只做 #1+#2+#3（会话 / 仲裁 / 所有权），`LaunchPlan` 与「星座单概念」下一轮 |
| Q3 | `SkyScene` 先按 `extension` 拆文件，不拆类型 |
| Q4 | 仲裁器吃「候选 + 时间」，不自己问场景 |
| Q5 | 不用 SPM 包做内部边界，用 `private(set)` + 命令方法在编译期挡 |
| Q6 | 验收硬指标见第六节；视觉零变化是硬约束 |

## 三、会话的形状

深度标准：现在的接口是 38 个可写属性，等于实现；目标是 **17 个命令 + 4 个只读值**。

```swift
@MainActor @Observable
final class SkySession {
    private(set) var phase: Phase
    private(set) var selection: Selection?
    private(set) var layers: LayerSet
    private(set) var reading: Reading?
    private(set) var timeOffsetHours: Double
    private(set) var fieldOfView: Float        // @ObservationIgnored

    func start() async
    func pause()
    func resume()
    func resize(to size: CGSize)

    func drag(_ translation: CGSize, phase: DragPhase)
    func magnify(_ magnification: CGFloat, phase: GesturePhase)
    func resetZoom()
    func tap(at point: CGPoint)

    func select(_ selection: Selection?)
    func focus(group: SkyGroup)
    func aim(at direction: SIMD3<Float>)
    func setLayer(_ layer: SkyLayer, visible: Bool)
    func setTimeOffset(hours: Double)
    func step(now: TimeInterval)
    func dismissReading()
}
```

**观察粒度是本轮的技术核心**，不是细节：

- 参与观察：`phase` / `selection` / `layers` / `reading` / `timeOffsetHours` —— 全是低频，用户看得见的变化。
- `@ObservationIgnored`：`scene` / `rig` / `fieldOfView` / `lastDrag` / `rigBeforePinch` / `isPinching` —— 拖动与捏合是 60Hz。
- 理由：`@State var rig` 每帧写会整块重算 body；进了 `@Observable` 之后反而能做到「写 rig 不惊动 body」，前提是 body 不读它。**一旦有人为了画读数去读 `fieldOfView`，60Hz 重算就回来了。**

仲裁器的接口（纯值，不 import RealityKit）：

```swift
struct AttentionArbiter {
    mutating func update(now: TimeInterval, candidates: Candidates) -> Reading?
    mutating func dismiss(_ target: Target)
    mutating func reset()
}
struct Candidates { var star: Star?; var constellation: Constellation?; var pattern: SkyPattern? }
```

三件事收进它一处：统一 `maximumStep`（星体有、星座星群没有）、统一优先级（星体 > 星座 > 星群）、统一重新武装（`dismissed` 只在离开天区时清，现在藏在 `resetConstellationTracking` 1298）。

## 四、38 个 `@State` 的归属

| 归属 | 数量 | 具体 |
|---|---|---|
| 会话 | 26 | `scene` `catalog` `rig` `attitude` `lastDrag` `zoomBase` `isPinching` `rigBeforePinch` `selected` `selectedGroup` `groups` `tonight` `motionActive` `showsConstellations` `showsAsterisms` `showsOutlines` `showsPatterns` `identifiedConstellation` `identifiedPattern` `guide` `guideVector` `currentRegion` `infoRegion` `observer` `perf` `tonightStamp` |
| 仲裁器 | 6 | `constellationHold` `constellationDismissed` `patternHold` `patternDismissed` `dwell` `regionStamp` |
| View 留下 | 6 | `showsCredits` `fengshenFocus` `showsFinder` `hud` `perfSummary` `diagnosticsStamp` |

判定规则（写给下一个人看，不是写给编译器看）：**用户离开这个页面时，希望它还在 → 会话；希望它消失 → View。** `fengshenFocus` 和 `showsFinder` 是弹层，回来再弹一次是 bug。

## 五、文件拆分

| 文件 | 现在 | 目标 | 内容 |
|---|---:|---:|---|
| `SkyView.swift` | 1444 | ≤ 400 | body、reality、手势转发 |
| `SkyChrome.swift` | — | ≈ 300 | 顶栏、底栏、时间滑块、提示条、性能读数 |
| `SkyCards.swift` | — | ≈ 420 | 星卡、星官卡、星座/星群标识卡、引导条、朝北、致谢 |
| `SkySession.swift` | — | ≈ 480 | 会话与命令 |
| `AttentionArbiter.swift` | — | ≈ 200 | 三目标仲裁 |
| `SkyScene+Build.swift` | 846 | ≈ 260 | 星点、连线、轮廓、星官、星群 |
| `SkyScene+Look.swift` | 〃 | ≈ 180 | 相机、视场、朝向、可见性、高亮 |
| `SkyScene+Query.swift` | 〃 | ≈ 220 | pick、天区判定、方向查询 |
| `SkyScene+Diag.swift` | 〃 | ≈ 120 | budget、pickDiagnostics、pickRoundtrip |

`SkyView` 那 400 行必须把卡片（610-1009，正好 400 行）搬走，否则数字目标不成立。

## 六、迁移节点

每个节点一次提交，单独可验收。

| 节点 | 做什么 | 验收 |
|---|---|---|
| N1 | `SkyScene` 按 `extension` 拆四个文件，语义不动 | 295 项绿；`SPACEWALKER_LAYERS=1` 截图逐像素不变 |
| N2 | 落地 `AttentionArbiter` + 测试，**不接线** | 新增 ≥ 8 项；旧行为不变 |
| N3 | 接线仲裁器，删 `constellationProgress` / `patternProgress` / `stepDwell` | `SPACEWALKER_DWELL=1` 日志中 `sky.region` 序列不变 |
| N4 | 会话落地：场景、姿态、视场、手势瞬时 | 拖动 / 捏合 / 双击 / 转屏四组截图；FPS 不劣于基线 |
| N5 | 搬选择、图层、时间、观察者 | `@State` 38 → 6；切路由往返状态还在 |
| N6 | View 按角色拆 `SkyChrome` / `SkyCards` | `SkyView` ≤ 400；截图逐像素不变 |

## 七、验收

- `SkyView` 1444 → ≤ 400 行；`@State` 38 → 6
- `SkyScene` 846 → 每个文件 ≤ 300 行
- 295 项测试 0 失败；仲裁器新增 ≥ 8 项
- 新增 1 条穿过会话的集成测试（见八-3）
- 真机 FPS 不劣于 `docs/gates/M2/sky-layers-2026-11-07.md`：avg 58.5–60 / min 28–46 / hitch ≤ 1.7% / thermal nominal
- 视觉零变化：同一组 `SPACEWALKER_*` 截图逐像素比对

## 八、重难点

### 1. 朝向三态没定死，搬完只是换皮

现在有三面旗子互相打架：`isAttitudeDriven`（设为 true 后**没有任何复位路径**）、`aimLocked`（`releaseAim` 复位）、以及 `apply(rig:)` 被 `RealityView` 的 update 每帧调用。039 修过一次同类问题，注释写着「这里漏了同一个守卫」。

搬进会话之前必须先把状态机写死成三态：**姿态驱动 / 手势驱动 / 定位锁定**，并明确「谁能让位给谁」。否则这堆 boolean 会原样漂进 `SkySession`，行数少了两百，语义一处没动。

顺带：`motionActive` 现在同时挡拖动（`guard !motionActive`）。归到会话后要留只读出口，否则底栏的「运动中」提示会失联。

### 2. 观察粒度错了，帧率会替你发现

`@Observable` 只失效「body 读过的属性」。这是好事，也是陷阱：把 `fieldOfView` 留在观察集合里、又让性能读数去读它，捏合时就是 60Hz 重建 body。同理 `rig`——一旦有人为了画调试角标去读 yaw，拖动就掉帧。

规则：`rig` / `fieldOfView` / `scene` / 全部手势瞬时量，一律 `@ObservationIgnored`。验收不能只看「能拖动」，要跑 `SPACEWALKER_FPS=1` 看读数。

### 3. 295 项测试证明不了重构正确

全仓 7 次 `SkyScene()` 没有一次调用 `build` / `pick` / `highlight`——`attach` 要 `RealityViewCameraContent`，测试造不出来。`ConstellationCoverageTests.positions()` 甚至把 `buildConstellations` 136-139 的建表逻辑抄了一遍再断言。

所以「测试全绿」在本轮几乎是空的。必须补一条能穿过会话的路径：给 `SkyScene` 抽一个 `SceneHosting` 协议（加实体、投影、命中），测试注入假实现。**这是本轮唯一一处「改结构」而不是「搬家」**，也正因为如此，它要单独一个节点先做完，不能混进 N4。

### 4. 转屏保尺度是视觉回归的头号来源

三个数合成一个的时候，`resize` 的判据必须原样保留：**只在长短边互换时缩视场**（同方向的高度变化不触发），双击复位回 `baseFieldOfView` 而不是死板的 60°。合错一步的现象是「横屏一进去就缩一半」或者「横屏双击复位又缩一半」，两种都只在转屏后出现，单屏截图抓不到。

### 5. `isBuilt` 早退会让会话停在「假 ready」

`build` 在 83-84 先 `isBuilt = true`，再在 151 因骨架为空提前 return——此时轮廓、星官、星群都没建（131-132 未执行），而后续 `build` 永远被 83 行挡住。`isReady` 只检查 `content` / `nodes` / `viewSize`，所以「ready」可能是空天。

会话的 `start()` 一旦依赖 `isReady`，就会拿着空天继续跑，而 `LaunchMode` 的高亮串会在空表上静默返回（044 踩过一次：卡片弹了、天上没亮线）。这个既有缺陷必须在 N4 之前修掉，否则会话把它固化成契约。

### 6. 轮询改事件，会把验收手段本身搞坏

`load()` 里有 6 处 `for _ in 0..<60 where ... { sleep 50ms }`。照抄进会话就是串行等待；改成 `isReady` 的一次性 continuation 才对。但时序会变：现在靠轮询「刚好等到」，改事件后可能抢在 mesh 就绪前触发。

`SPACEWALKER_*` 是 headless 模拟器下唯一的验收手段（点不动界面），所以改完必须逐串重跑并录日志，不能只看编译过。

### 7. 场景常驻是看不见的成本

Q1 选了「切路由保留会话」，代价是 2996 颗星的星点 mesh 与 16 个实体常驻。`pause()` 必须停掉 `DeviceAttitude` 与 `SkyObserver`（CoreMotion / CoreLocation）以及两个无句柄的 `Task` 循环，否则用户在太阳系页面时手机仍在按 67Hz 采姿态。

现象是发热与耗电，截图与 FPS 都看不出来，只能靠真机 `thermal` 字段与后台日志确认。
