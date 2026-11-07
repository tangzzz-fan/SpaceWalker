# 032 时间滑块：抖动与跳变的成因与重做方案

## 现象

拖动 ±12h 滑块时，星空表现为：**前一段不动、偶尔猛跳一大段、过程中发涩**。

## 第一性拆解

时间滑块只改一件事：`field` 节点的 orientation（地平旋转）。这个量必须随 offset **连续单调**变化。任何不连续只能来自下面四处，逐一核对代码（`eba3e50`）后确认**四处全部命中**。

（先排除一个误判：滑块本身带 `if observer.stage == .ready` 条件，未定位时不显示，所以不存在「未开今夜拖了没反应」。但它带来另一个小问题——stage 从 requesting 跳到 ready 时滑块突然出现，顶栏高度变一下，属于布局抖动，与星空无关。）

### ① 1 秒节流吞掉拖动

`SkyView.swift:722-729`
```swift
let now = ProcessInfo.processInfo.systemUptime
guard now - alignmentStamp > 1 else { return }
alignmentStamp = now
```

同一函数被三处调用：
- `SkyView.swift:238` 时间滑块 `onChange`（拖一次触发几十次）
- `SkyView.swift:704` 运动回调（**67 Hz**）
- `SkyView.swift:82` stage 变化

运动回调每帧都在刷新 `alignmentStamp`。于是拖动期间几乎每次 `onChange` 都被 `guard` 丢回；只有恰好某帧没抢到时才生效一次。

结果就是"一秒才动一帧，且动的是最新值"——阶跃跳变。这是**节流层级错位**：节流原本是为"磁力计持续校准"和"区域识别"设计的，却被套在了"必须跟手"的时间路径上。

顺带一处浪费：运动回调每帧都在算恒星时 + 建四元数，只为设一个与姿态无关的常量。

### ② 时间基准每次重采样

`SkyObserver.swift:108-114`
```swift
func shiftedNow() -> Date {
    Date().addingTimeInterval(timeOffsetHours * 3600)
}
```

每次调用都取新的 `Date()`。同一个 offset 在 t 与 t+1s 得到的 orientation 差 15 角秒（可忽略），但它意味着**偏移量不是一个稳定状态，而是一个随时间漂移的函数**。叠加播放动画或多次重算时，会产生"同一位置每次渲染略有不同"的隐性抖动。

### ③ 步进粒度 = 7.5°

`SkyView.swift:219`
```swift
Slider(value: $timeOffset, in: -12...12, step: 0.5)
```

0.5h = **7.5°**。滑块宽 140pt，全程 48 格，每格约 2.9pt。手指每移动 3pt，天空就跳 7.5°（约 4 个满月直径）。这是"跳"的第二个来源，且与 ① 叠加后变成"每隔一段跳一大格"。

### ④ 订阅粒度过粗

`timeOffset` 是 `SkyView` 的 `@State`。它一变，**整个 `SkyView.body` 重算**：`topBar`、`hintBar`、`reality`（`RealityView` 的 `update` 闭包跟着跑）、`skySubtitle`（内部又调 `currentSiderealDegrees()`，再算一次儒略日与 GMST）。

拖动 60 次/秒 → 顶层视图树重建 60 次/秒。这是"发涩"的体感来源。

另有一处状态重复：`timeOffset`(视图 @State) 与 `observer.timeOffsetHours`(@Observable) 两份，靠 `onChange` 单向同步；`disable()` 不清 `timeOffsetHours`。今天只有滑块一个写入方还看不出问题，加播放按钮必然分叉。

## 修复方案

### A. 拆开「应用对齐」与「校准节流」（必做）

```swift
// 无节流，只做一件事
func refreshField() {
    guard observer.isOn, let q = observer.fieldOrientation() else { return }
    scene.setField(orientation: q)
}
```

- 时间滑块、stage 变化、校准完成 → 调 `refreshField()`
- 运动回调 → **不再调用**（field 与姿态无关）
- 节流只保留给 `observer.calibrate`（它内部已有 `firstLock/topNorthUpgrade` 锁，甚至可以把外层节流去掉）

收益：拖动跟手、67Hz 回调少一次 GMST 计算、语义正确。

### B. 固定时间基准（必做）

```swift
private var timeBase: Date = .now

func setTimeOffset(hours: Double) {
    timeOffsetHours = min(max(hours, -24), 24)
}

func shiftedNow() -> Date {
    timeBase.addingTimeInterval(timeOffsetHours * 3600)
}

func resetClock() { timeBase = .now; timeOffsetHours = 0 }
```

`timeBase` 在 `enable()`、`resetClock()` 时刷新。同一 offset 恒定，播放动画可预测。

更彻底的做法是抽一个 `SkyClock`（`base` + `offset` + `rate` + `isPlaying`），作为唯一真相源，`SkyView` 只读。滑块与播放共用同一个 setter。

### C. 步进细化（必做）

去掉 `step: 0.5`，改连续拖动，只在显示层格式化：

```swift
Slider(value: offsetBinding, in: -12...12)
```
```swift
private var timeOffsetLabel: String {
    if abs(offset) < 1.0 / 120 { return "此刻" }
    let minutes = Int((offset * 60).rounded())
    let sign = minutes < 0 ? "-" : "+"
    let m = abs(minutes)
    return String(format: "%@%d:%02d", sign, m / 60, m % 60)
}
```

理由：0.5h 吸附是"跳"最直接的来源，且它没有任何交互收益——用户拖这个控件就是为了连续看星空转。1 分钟粒度 ≈ 0.25°，肉眼完全察觉不到台阶。

### D. 交互换挡（暂不做）

| 项 | 现在 | 可做 |
|---|---|---|
| 数值显示 | `+3.0 h` | `22:40 · 3 小时后` |
| 刻度 | 无 | 现在 / 日落 / 午夜 / 日出 |
| 播放 | 无 | 1× / 60× / 600× |

播放比拖动更适合"讲季节"：让星空自己转。但要驱动 60Hz 的时间推进，不能走 SwiftUI 每帧状态更新，得沿用姿态那条"直接写 entity"的路子。这一轮不做。

### E. 订阅粒度下沉（性能）

把滑块整体拆成独立子视图：

```swift
private struct TimeScrubber: View {
    @Environment(SkyObserver.self) private var observer   // 只订阅这里
    let onChange: () -> Void
    var body: some View { ... }
}
```

父 `SkyView` 不再持有 `timeOffset`，`body` 就不会因拖动重算；`RealityView` 的 `update` 也不会被无谓触发。

## 验证

不做观感判断，用可测指标：

1. **节流吞没率**：临时在 `applyAlignment` 计数「调用次数 / 实际应用次数」，拖一次滑块（约 2s）后读日志。修复前应接近 30:1，修复后应为 1:1。
2. **连续性**：`offset` 从 -12 连续加到 +12（步长 1 分钟），采样 `field.orientation` 推出的恒星时，序列必须单调且差值恒定（15.041°/h × Δt），无跳变。
3. **时间基准固定**：同一 offset 连续调用 `currentSiderealDegrees()` 两次（间隔 1 秒），返回值必须完全相同；`resetClock()` 后才随真实时间前进。
4. **帧率**：真机拖动 10 秒，`Instruments` 掉帧率应 < 1%；修复前记录基线对比。
5. **单测**：
   - `setTimeOffset(hours:)` 夹在 ±24；
   - 同一 base 下 `shiftedNow` 对同一 offset 恒定；
   - `SkyObserver.fieldOrientation()` 在 offset 0 与 +1h 时的四元数夹角 = 15.041°；
   - 现有 223 项全部保持通过。

## 不做

- 不对时间做插值平滑。拖动必须 1:1 跟手，插值会引入延迟，反而更"抖"。
- 不保留 `step: 0.5` 的吸附。它是当前跳变最直接的来源。
- 不在这一轮做播放与刻度（见 D）。

## 实施结果

| 项 | 落地 |
|---|---|
| 去节流 | `applyAlignment()` → `refreshField()`，删掉 `alignmentStamp` 与 1 秒判断；运动回调不再调用，改为 `observer.calibrate(...)` 返回 `true` 时才刷新 |
| 时间基准 | 新增 `SkyClock`：`offsetHours == 0` 时跟随真实时间，非零时定格在 `base + offset`；从「跟随」切到「定格」的那一刻把 `base` 设为当时时刻 |
| 单一真相 | 删掉 `SkyView.timeOffset` 这个 `@State`，滑块直接绑 `observer.clock`，`disable()` 与重置不再需要双向同步 |
| 步进 | `Slider(step: 0.5)` → 连续拖动；标签从 `+3.0 h` 改为 `+3:00` |
| 今晚榜单 | `refreshTonight()` 加 0.4 秒节流，松手时强制刷新一次（避免拖动时每帧重算 31 个星座） |

**实测（模拟器，31.251°N / 120.605°E）**

| 偏移 | 恒星时 |
|---|---|
| 0h | 5.0° |
| +3h | 50.2° |

差 45.2°，理论 3 × 15.041 = 45.12°，误差 0.08°（读数精度 0.1°）。画面星座位置随之整体西移，标签与顶栏均显示 `+3:00`。

**连续性与确定性**（新增 10 项单测）

- 1 分钟步长遍历 ±12h 共 1440 步，每步恒星时增量恒定 0.2507°（min == max），无反向跳
- 同一 offset 间隔 600 秒取两次 `instant`，完全相等
- ±24 夹取、reset 归零、30 秒内视为「此刻」

233 项单测 0 失败（新增 10 项）。

**未做**：播放与日落/午夜刻度（见 D），订阅粒度下沉（见 E，拖动时父视图仍会重算，实测未见掉帧，留待需要播放时一并处理）。
