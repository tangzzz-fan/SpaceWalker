# 054: 切走即停

**What to build:** 会话离开路由时停掉姿态采集、定位与两个后台循环，回来再恢复；场景保留不重建。B 阶段要求 2000 实例下 ≥55fps，后台仍在 67Hz 采姿态是白烧的电。

**Blocked by:** 052

**Status:** done

- [x] 切走后后台循环停止（模拟器与真机各验一次）
- [x] 真机往返 10 分钟，thermal 全程 nominal（详见下文实测）
- [x] 回来后姿态 **12ms** 恢复跟踪（要求 ≤1s）
- [x] 相机与定位权限状态不受影响（`observer.disable()` 只停更新，不动权限）
- [x] 310 项单测 + 1 项 UI 往返测试 0 失败
- [ ] 电量曲线：**无法测量** —— 本机没有 libimobiledevice，`devicectl info details` 不带电量字段

## 实现记录

- 真正的泄漏不是姿态，是**两个无主 `Task`**：`load()` 里 `Task { while !Task.isCancelled { ... } }` 是无结构任务，`.task` 取消的是 `load()` 本身，这两个循环不会跟着停。页面走了，80ms 停留探针和 1s 性能采样仍在转。
- 修法：`SkySession.track(_:)` 收任务句柄，`pause()` 统一取消再 `stopMotion()`，页面 `.onDisappear` 改调 `session.pause()`。
- 证据：往返测试里 `sky.pause tasks=1` 打在 10403ms，之后 12 秒空白，直到 22700ms 重新装载才恢复 `sky.perf`。返回后方可确认 `load()` 会重建任务，不会越切越多。
- 未跑的两项需要 iPhone（`tools/device.sh` 依赖 `connection.transportType == wired`）。当前 `devicectl` 没有连线设备，故只在模拟器上验了「停」，没验「热」。补测命令：`SPACEWALKER_LAYERS=1 bash tools/device.sh run`，切到太阳系停留 10 分钟后取 `sky.perf ... thermal=` 与电量。

## 真机实测（iPhone 16 Pro / UDID 00008140-000A288836FB001C）

`SKYCHECK_AWAY_SECONDS` 参数化往返时长，同一测试先跑 20 秒冒烟再跑 600 秒正式；用例本身通过（623.7 秒）。

| 指标 | 实测 |
|---|---|
| 离场时长 | 600.4 s（`sky.pause` 9458ms → 回场 609858ms） |
| 离场窗口内 sky 日志 | **0 条**（只有太阳系自己的 `probe.fps`） |
| 姿态恢复 | `sky.motion started` 609858ms → 首帧采样 609870ms，**12 ms** |
| thermal | 全程只有 `nominal`，回场首条 `sky.perf` 仍是 nominal |
| 回场帧率 | avg 59.9 / min 35.3 / hitch 0.0% |
| `sky.session boot` | 1 次 |
| `sky.catalog` | 1 次 |

未测项要如实说：电量没有可读接口。能测的是「离场期间没有任何 sky 活动」，这比电量曲线更直接——不跑的循环不耗电。
