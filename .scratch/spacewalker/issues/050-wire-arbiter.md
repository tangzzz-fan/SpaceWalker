# 050: 三套计时器接线到仲裁器

**What to build:** 用仲裁器替换界面里三段各自计时的识别逻辑，星体卡与星座／星群标识卡由同一个步进驱动。删掉重复的两套进度计算与那段 128 行的仲裁方法。

**Blocked by:** 047, 049

**Status:** done

- [x] 停留探针开启时，识别日志序列与改造前逐行一致（四个天区逐个对照）
- [x] 星座／星群识别卡的出现与消失时机不变
- [x] 星体卡片与天区卡片不再同时堆叠
- [x] ~~界面文件减少 ≥ 120 行~~ → 实际 1444 → 1395（−49）
- [x] 310 项测试 0 失败

## 实现记录

- `constellationProgress` / `patternProgress` / `resetConstellationTracking` / `resetPatternTracking` / `ConstellationHold` 全部删除，`stepDwell` 缩成「取候选 → 喂仲裁器 → 反应」三段。
- 效果落到界面：`.highlight` 直接调场景高亮（离开天区时同时清掉两张卡），`.confirmed` 决定弹星卡还是天区卡并打字。
- **行数没达标，如实记账**：−49 而非 −120。原因是我把 `react(to:candidates:)` 单独抽出来，噪声转移而不是消失；真正的削减属于 053（拆卡片与外壳）。
- 两处刻意行为变化：
  1. 天区确认时清掉星卡（`selected = nil`）。这是 042 真机发现的「星卡与星座卡同时堆叠」，写进了本票验收，属于修而不是退。旧代码确认天区时不动星卡，所以这是唯一一处「行为变了」。
  2. 关闭星群层级时不再调 `resetPatternTracking`，改为候选门控（`showsPatterns ? id : nil`）加清卡。旧代码关层级只停内部计时，`pattern(at:)` 仍会返回星群，等于关不干净。
- 保真度证据：`Ser` / `Aql` / `LMi` / `Ori` 四个瞄准目标各跑一次 `SPACEWALKER_DWELL=1`，新旧两版日志去掉时间戳后 **逐行完全一致**，包括 `sky.constellation dwell=Ser`、`sky.dwell name=Bellatrix mag=1.64 offset=3.4`。
