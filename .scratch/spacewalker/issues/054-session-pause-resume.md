# 054: 切走即停

**What to build:** 会话离开路由时停掉姿态采集、定位与两个后台循环，回来再恢复；场景保留不重建。B 阶段要求 2000 实例下 ≥55fps，后台仍在 67Hz 采姿态是白烧的电。

**Blocked by:** 052

**Status:** done（两项真机项待补）

- [x] 切走后后台循环停止（`sky.pause tasks=1` 之后 12 秒内没有任何 `sky.perf`）
- [ ] 真机往返 10 分钟，thermal 保持 nominal，电量无异常下降 —— **未跑，当前没有连线真机**
- [ ] 回来后姿态在 1 秒内恢复跟踪 —— **未跑，模拟器没有 CoreMotion**
- [x] 相机与定位权限状态不受影响（`observer.disable()` 只停更新，不动权限）
- [x] 310 项单测 + 1 项 UI 往返测试 0 失败

## 实现记录

- 真正的泄漏不是姿态，是**两个无主 `Task`**：`load()` 里 `Task { while !Task.isCancelled { ... } }` 是无结构任务，`.task` 取消的是 `load()` 本身，这两个循环不会跟着停。页面走了，80ms 停留探针和 1s 性能采样仍在转。
- 修法：`SkySession.track(_:)` 收任务句柄，`pause()` 统一取消再 `stopMotion()`，页面 `.onDisappear` 改调 `session.pause()`。
- 证据：往返测试里 `sky.pause tasks=1` 打在 10403ms，之后 12 秒空白，直到 22700ms 重新装载才恢复 `sky.perf`。返回后方可确认 `load()` 会重建任务，不会越切越多。
- 未跑的两项需要 iPhone（`tools/device.sh` 依赖 `connection.transportType == wired`）。当前 `devicectl` 没有连线设备，故只在模拟器上验了「停」，没验「热」。补测命令：`SPACEWALKER_LAYERS=1 bash tools/device.sh run`，切到太阳系停留 10 分钟后取 `sky.perf ... thermal=` 与电量。
