# 049: 关注度仲裁器

**What to build:** 一个纯值仲裁器：喂「候选（星体／星座／星群）+ 当前时间」，吐「该确认哪一个」。它统一三件现在分散的事——单步最大推进（只有星体那套有）、优先级（星体 > 星座 > 星群）、关闭后的重新武装（现在只在离开天区时清）。本票只建模块与测试，不接线。

**Blocked by:** None (can start immediately)

**Status:** done

- [x] 新增 ≥ 8 项测试（实际 17 项），覆盖：0.6s 确认、单步上限、三目标优先级、关闭后仍指同一天区不重弹、离开天区后重新武装
- [x] 仲裁器不依赖场景与 UI，可脱离 RealityKit 单测
- [x] 生产代码尚未引用它，行为零变化（全仓零调用点）
- [x] 310 项测试 0 失败

## 实现记录

- 接口：`step(now:candidates:) -> Step`，`Step` 只含 `progress` 与 `effects`（`.highlight` / `.confirmed`），不产生副作用。候选用 `String` 标识星座与星群，避免把 `Constellation` / `SkyPattern` 拖进模块。
- 星体轨道复用 `DwellSelector`（1.5 衰减、0.1 上限、0.3 重新武装原样保留）；天区轨道用同一 `delta` 累加，**这是唯一一处有意差异**——旧代码用 `now − since` 的墙钟，卡顿 0.5 秒会直接推满进度，新的按单步 0.1 秒封顶。规格要求「统一单步最大推进」，代价是卡顿时天区计时变慢。
- 评审抓到并修掉三处保真度偏差：
  1. 确认帧把 `progress` 打回 0（旧值恒为 1.0），环会闪一帧。改为始终取 `dwell.progress`。
  2. 切换天区时把「已关闭」弄丢。旧代码只在离开**全部**天区时清 `dismissed`，现在照旧保留，并补 `testDismissalSurvivesSwitchingRegions` 钉住。
  3. `reset()` 语义被放大成清空三者，接上线后点一下星就会拆掉星座卡。拆成 `reset()`（全清）与 `resetStar()`（只复位星体，对应旧的 `dwell.reset()`）。
- `dismiss` 改为把 `track.confirmed` 放下、由 `dismissed` 拦重复确认——否则 `dismissed` 是死代码。变异检验：摘掉该判定后 `testDismissedConstellationStaysQuietUntilLeaving` 立即变红，说明测试有牙齿。
- 保真度最终由 050 的日志比对裁定：本票内只能证明它符合「对旧代码的读法」，真正的等价要在接线后比 `sky.region` / `sky.constellation dwell` 序列。
