# 084 · 「再入」点击无效果：锁定态零反馈 + 三 tab 控件全量可达性扫描

日期：2026-11-17 ｜ 触发：董事长真机实测「点击天宫一号的再入，我没看到效果，同类型都需要检查一下」
关联：080 门禁（B4/B5）、081（死按钮）、083（不可达分支）、079 diff（C1/C4/C7）、PRD-UI:232

> 状态：**F1–F4 已实施 + 真机取证闭环（2026-11-17，06d2234）**。F5 登记不动。
> 单测 412 项 0 失败 + 模拟器 UI 验收 4 条 + **真机 UI 验收 4 条全部通过**（20:17，有线）。

## 1. 现象

真机（Tango，iPhone 16 Pro，iOS 27.0，新包 com.tango.xingcha 全新容器）天宫默认态，
点底部上下文控件「再入」→ 画面、状态条、按钮全部无变化，无任何提示。

## 2. 本质（机制链，全部有代码坐标）

```
点击「再入」(ChromeState.swift:323, 恒常渲染)
  → actions.control .tiangongReentry (TiangongView.swift:365-366)
      if session.canStartReentry { session.startReentry() }   ← 无 else，零反馈
  → canStartReentry (TiangongSession.swift:138-140)
      = TiangongReentry.isUnlocked (TiangongReentry.swift:91-93)
      = mission.phase == .complete && hasReadMilestones
  → 全新安装：mission = .start() = .disassembly，hasReadMilestones = false
      （TiangongSession.swift:39,44；无持久化，每次冷启动归零）
  → guard 静默 return（TiangongView:366 外层 if + TiangongSession:149 内层 guard 双保险静默）
```

**这不是死按钮（081 型：无 handler），也不是不可达分支（083 型：mode 派生不出）——
handler 存在、控件可达、副作用被解锁门挡住，且挡住时零反馈。**

**设计稿早已定义正确行为，实现漏做了**：

> `docs/design/PRD-UI-v1.md:232`：「再入彩蛋未解锁 | **按钮置灰 + 一行 11pt 说明
> 『完成三步任务并看过史实后解锁』，点击时提示，不隐藏**」

实现现状逐条对照：置灰 ✗（ChromeControl 无 isEnabled 字段，contextControls 不接 session 状态）、
说明 ✗（无任何解锁提示文案）、点击提示 ✗（静默 return）、不隐藏 ✓（唯一做对的一条）。

### 为什么「没看到效果」是必然而非偶发

全新容器 → 必然锁定 → 必然静默。要解锁必须走完整条链：
拆满 4 模块（disassembly→assembly）→ 全部装回（assembly→docking，TiangongMission.swift:51-52）
→ **进入对接玩法并对接成功**（docking→complete，TiangongMission.swift:64-65）
→ 打开一次史实面板（TiangongView.swift:78-80 markMilestonesRead）。
而第 3 步在生产 UI 里**不可达**（见 §3 F2）——即当前版本「再入」对普通用户是**永久锁死**的，
只有取证开关 `SPACEWALKER_TG_DOCK=1` 能进对接。这解释了全部现象，包括「为什么设计稿
写了置灰+说明」——设计时就知道用户会长期处于锁定态。

## 3. 同类全量扫描（三 tab 全部 chrome 控件 × 全部 mode）

谓词沿用 083 升级版：结构（handler 存在）∧ 可达（mode 能派生出该控件）∧ 副作用（点击有可见变化）。
本轮新增第四维：**反馈（被 guard 挡住时用户是否被告知）**。

### 3.1 发现项

| # | 控件/分支 | 结构 | 可达 | 副作用 | 反馈 | 定级 |
|---|---|---|---|---|---|---|
| F1 | 天宫「再入」tiangongReentry | ✓ | ✓ | 锁定态 ✗ | ✗ 静默 | **P1 违反 PRD-UI:232**（本票主案） |
| F2 | 天宫对接入口 beginDocking | ✓ | **生产 ✗** | — | — | **P1 任务链断裂**（083 型第二例） |
| F3 | 天宫「粗调/精调」chrome 双控件 | ✓ | 仅 .docking（因 F2 生产不可达） | toggle 有（dockingCard 标题反映） | 双按钮都 toggle、无选中态区分 | P2 交互歧义（随 F2 暴露） |
| F4 | 太阳系「流速」spaceRate | ✓ | ✓ | ✓ rate 循环 | ✗ 档位无处显示（状态条只有「运行中 · 第 N 天」，PRD-UI:183 要求「x 天/秒」） | P2 反馈缺失 |
| F5 | 星图「姿态」skyAttitude | ✓ | ✓ | ✓ followsAttitude 切换 | ✗ 无选中态/状态文案（isManual 时拖拽行为变化但用户无从得知模式） | P3 观察项 |
| F6 | 星图「今夜」skyTonight | ✓ | ✓ | ✓ observer.enable/disable | 部分（statusText 零消费 = 083 已批方案二） | 并入 083，不重复开票 |

F2 细节：`beginDocking()` 全仓只有两个调用方——`SPACEWALKER_TG_DOCK=1` 启动开关
（TiangongSession.swift:81-82）与 `resetDocking()`（:419，「重试」按钮，仅 dockingCard 内、
失败态才出现）。**没有任何 chrome 控件或卡片按钮从 normal/assembly 态发起对接**。
mission 推进到 .docking 后（装回最后一个模块，closure 动画 + 成功震动），
用户面对的是：状态条不变、无对接入口、无「下一步做什么」提示——任务链在最后一环断头。
079 diff C4 用取证开关截图验过「对齐」，**生产可达性从未被验收**（079 漏检第三例，
前两例见 findings 2026-11-16/11-17）。

### 3.2 通过项（副作用可见，无需动）

- 星图：找星/取消/完成（sheet 开合）、定位（guide 箭头）、图层+三类目（sheet）、
  城市（finder sheet）、重置（时钟归零+状态条「此刻」）、星卡选中（卡片+状态条）。
- 太阳系：全览/聚焦（相机复位）、暂停（状态条「已暂停」✓ SpaceView:84-87）、
  轨道（轨道环显隐）、天体卡。
- 天宫：开始拆解（lab 分离+卡片）、分离/装回（几何动画+主按钮标题翻转）、
  剖面/工程图（模式切换+状态条+专属控件组）、退出剖面/工程图、复位视角、
  正/侧/俯视图（相机）、史实/来源（sheet）、再入态「跳过」（skipReentry 有 guard
  reentryActive 但该 mode 下恒真，可达即有效）、再入卡「再看一次/关闭」、
  对接卡内粗调/精调小按钮（标题反映当前档 ✓）、重试/重玩/最后一圈（条件渲染 ✓）。
- 083 已登记：tonight mode 不可达（.tonight 无产出方）——不重复计。
- 081 已删：tiangongHold / tiangongInteriorLabels 死按钮——本轮扫描确认无残留。

## 4. 拟定方案（待董事长批）

### F1 再入锁定反馈 —— 拟定：按 PRD-UI:232 原文实现（不是新设计，是补漏）

1. `ChromeControl` 增加 `isEnabled: Bool = true`；`ChromeState.derive` 增加
   `reentryUnlocked: Bool = false` 入参，天宫 default 态「再入」置 `isEnabled: reentryUnlocked`。
2. ChromeLayout 上下文控件渲染置灰态（沿用 primary 的 disabledText/surface2 token）；
   **不真 disabled**——PRD 要求「点击时提示」，置灰但可点。
3. 点击锁定态「再入」→ 状态条 detail 显示「完成三步任务并看过史实后解锁」（11pt 说明
   与状态条 detail 同源，ChromeTokens.captionSize），3 秒后回落默认 detail；
   同时 SessionLog 记 `tiangong.reentry locked=1`（取证可查）。
4. TiangongView syncMode/相关 onChange 把 `session.canStartReentry` 派生进 chrome
   （新 ChromeAction `.setReentryUnlocked(Bool)` 或并入现有 recompute 通道，实施时定）。
5. TDD：ChromeStateTests 先红（锁定态 isEnabled=false + derive 默认值）→ 绿；
   UI 取证：真机/模拟器锁定态截图（置灰+点击提示）+ 解锁态回归（TG_DOCK+TG_HISTORY
   走通后按钮恢复暖金可点）。079 diff C1 补一行「再入置灰态」对照。

代价：ChromeState 纯函数签名 +1 参数（默认值兼容既有 390 项）；约 60-80 行含测试。
反方：也可以 simplest「点击弹 toast」不动 ChromeState——但置灰是 PRD 明文，
且不可点状态不置灰会继续误导用户「点了没反应是 bug」（本次董事长实测即此感受）。

### F2 对接入口 —— 拟定：mission 到 .docking 时自动 beginDocking（续 070 降级路线）

装配完成（closure 动画）后**自动进入对接**：`advanceMission` 的 assembly→docking 分支
（TiangongSession.swift:481-484）追加 `beginDocking()`。理由：
- 三任务串联是 PRD 主线（TiangongMission 注释「三任务串联：拆解→装配→对接」），
  拆完装完自动进下一环符合「任务流」心智，不需要用户找入口；
- 070 已把「看过姿态调整」降级为史实卡，对接作为第三任务保留玩法但入口自动化，
  与既有降级方向一致；
- 不加新 chrome 控件（076 收敛：default 态 ≤3 上下文控件已满）。
- 风险：beginDocking 会 `separated.removeAll()`（装配完成时本就为空，无副作用）；
  closure 动画与对接相机切换的衔接需实测（TDD + 真机走通全链）。
反方：也可以给 card 态加「开始对接」按钮——但违反 ≤3 控件收敛且多一步操作；
或砍掉对接任务直接 complete——动 PRD 主线，须董事长明确裁决才考虑。

### F3 粗调/精调 —— 拟定：随 F2 顺手修，双按钮改「当前档高亮」

chrome 双控件各自 setSelected 语义（点粗调=切到粗调，点精调=切到精调，当前档 isSelected
高亮），替代现在「两个都 toggle」；dockingCard 内小按钮保留。ChromeControl 加
`isSelected: Bool = false`（与 F1 isEnabled 同批加字段，一次回归）。约 20 行含测试。

### F4 流速档位 —— 拟定：状态条补「x 天/秒」（PRD-UI:183 原文）

`updateStatus()`（SpaceView.swift:84-87）拼上 rate：「运行中 · 第 N 天 · x 天/秒」，
rate 变化 onChange 触发。079 diff B1 行同步补注。约 10 行含测试。

### F5 姿态模式 —— 拟定：只登记不动（P3）

isManual 切换有拖拽行为差异但无文案；候选方案是状态条 detail 变「手动浏览 · 拖动环顾」。
涉及 A1 状态条文案（077 刚对齐稿），动它要回改稿——收益小，建议 1.0 不动，登记观察。

### 实施顺序（批后）

F1+F3 同批（ChromeControl 字段一次加齐）→ F2（任务链）→ F4（状态条）→ 全量回归 390+新增
→ 真机全链走通取证（拆解→装配→自动对接→对接成功→史实→再入解锁→三拍播放）
→ 079 diff C1/C4/B1 更新 → 080 B4 签字材料补齐。
**与 081/083 的关系**：084 是 080 门禁期间发现的 P1 缺陷，建议与 081/083 同批在
080 签字后实施（080 盲测 B1 用当前包不受影响——盲测看首屏与三视角，不走任务链）；
若董事长认为 F2 任务链断裂影响 B1 盲测观感，可提前单独实施 F2，请裁决。

## 5. 证据

- 代码坐标全部见 §2/§3（HEAD f6df7a6）。
- 真机现象：董事长 2026-11-17 07:40 前后实测（新包全新容器，必然锁定态）。
- 设计依据：PRD-UI-v1.md:232（置灰+说明+点击提示）、:183（x 天/秒）、:197（C4 粗调/精调）、
  :200（C7 最后一圈）；079 diff C1（任务条已裁「设计意图不验收」——注意：任务条不验收
  ≠ 任务链可以断，F2 是功能可达性缺陷不是 UI 对照差异）。
## 6. 实施记录（2026-11-17，06d2234）

- **F1**：`ChromeControl.isEnabled` + `derive(reentryUnlocked:)`；锁定态置灰但可点
  （PRD「点击时提示」），点击 → 状态条 11pt「完成三步任务并看过史实后解锁」3 秒回落
  （token 防竞态）+ SessionLog `tiangong.reentry locked=1`。
  UI 验收 testReentryLockedTapShowsHintThenFallsBack 通过；
  证据 084-reentry-locked-gray.png / 084-reentry-lock-hint.png。
- **F2**：`advanceMission` assembly→docking 分支追加 `beginDocking()`；
  单测 testClosureAutoBeginsDocking / testReentryUnlocksAfterChainAndHistory 覆盖全链。
- **F3**：`setControlMode(_:)` 显式设档（同档不翻转），chrome 双控件 isSelected 高亮当前档；
  dockingCard 内小按钮保留 toggleControlMode（内部改走 setControlMode）。
- **F4**：`SolarSystemState.rateStatusText/statusDetail` 纯函数，状态条
  「运行中 · 第 N 天 · x 天/秒」，daysPerSecond onChange 即时上屏；
  UI 验收 testSolarRateVisibleInStatusLine 通过（顺带修正 LandscapeUITests
  既有笔误 MODE=space→solarSystem，该值从未匹配过 initialRoute）。
- 真机全链取证（拆解→装配→自动对接→成功→史实→再入解锁→三拍）：
  设备 2026-11-17 08:13 无线掉线（unavailable），待重新可达后补；
  链路逻辑已由单测全覆盖，真机取证为补充证据非逻辑验证。

## 7. 真机全链取证记录（2026-11-17 20:10–20:18，Tango iPhone17,1 / iOS 27.0，有线）

**开关链日志**（084-device-chain-xingcha.log）：
`boot separated=4 → disassembly restored=4 → docking begin → attach modules=5`
——四段分离态启动，attach 时 beginDocking 收拢（F2 同函数），神舟接近。

**截图证据**（docs/gates/M3/）：
- 084-device-chain-history.png：对接态「交会对接 · 稳定接近」+ 轴向距离卡 +
  **粗调金色高亮（F3 真机实证）** + 模型合拢 + 神舟在侧
- 084-device-history-sheet.png：史实面板（2011-09-29 发射 / 2016-03-16 终止 /
  2018-04-02 再入南太平洋中部 / 任务里程碑 / 出处第 15 条）——markMilestonesRead 触发点
- 再入三幕 + 终幕（TG_REENTRY + TG_FREEZE 冻结时钟定点拍摄）：
  - 084-device-reentry-coast.png：t=3 滑行幕，完整组合体，「轨道高度衰减」
  - 084-device-reentry-heating-breakup-early.png：加热幕，橙红烧蚀，「再入大气层 · 气动加热」
  - 084-device-reentry-breakup-late.png：t=19 深解体，翼已消失舱段烧蚀，「结构解体」
  - 084-device-reentry-card.png：终幕史实卡「再入大气层 2018-04-02 南太平洋中部」+ 再看一次/关闭

**真机 UI 验收 4 条全过**（/tmp/spacewalker-084-device-ui5.log，xcresult 在 build/Logs/Test/）：
testCutawayInteriorLabelsVisibleAndAccessible 12.8s（081）/
testReentryLockedTapShowsHintThenFallsBack 14.7s（F1 置灰点击提示+3s 回落）/
testSolarRateVisibleInStatusLine 11.4s（F4）/
testTonightAlignmentShowsSelectionAndStatus 9.4s（083）。

**口径登记（不代裁）**：
- 生产路径「装配完成→自动对接」的触发分支由单测 testClosureAutoBeginsDocking 覆盖；
  真机取证用 TG_DOCK 开关直达 beginDocking（同一函数），交互装配段无头不可驱动。
- docked→complete→史实按钮出现→再入解锁的生产交互链由单测
  testReentryUnlocksAfterChainAndHistory 覆盖；真机以开关+UI 测试分段实证。
- TG_HISTORY 与 TG_DOCK 同开时史实面板被对接态覆盖（syncMode 优先级 docking>history），
  系开关组合局限非生产缺陷（生产史实入口在 complete 后）。
- **exit 74 排障**：残留 runner 进程占用 IDE 测试通道，清场即过——
  findings 已写（.scratch/findings/2026-11-17-真机UITest-runner-exit74-*.md）。

084 全部范围销账。
