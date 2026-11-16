# 080 · 真机帧率取证 runbook 与本次取数（待人工判定）

日期：2026-11-15 ｜ 关联：门禁项 3、PRD NFR-01、票 068

> agent 只负责编译、安装、启动、抓 runtime log 与截图，**不判定达标**。
> 「下限」的口径、基准机型是否等价、以及是否通过，全部由人裁决。

## 1. 判据口径纠错（重要）

`080-human-gate-checklist.md` 原写「60 秒平均 ≥60fps、下限不掉出预算」，与仓库权威口径不符。
按 `docs/agents/issue-tracker.md`「issue 与 PRD 冲突时以 PRD 为准」，以 PRD 为准：

| 来源 | 阶段 | 平均 | 下限 | 采样 |
| --- | --- | --- | --- | --- |
| `docs/PRD.md` NFR-01 | A / B（太阳系 / 星图） | ≥ 55fps | ≥ 30fps | 真机 **30s 录屏** + 帧率统计 |
| `docs/PRD.md` NFR-01 | C（天宫一号） | ≥ 25fps | ≥ 20fps | 同上 |
| `docs/PRD.md` NFR-04 | A / B 长时 | 第 10 分钟平均 ≥ 52fps，`thermal ≤ .fair`，25℃ | — | 10 分钟曲线（本批未测） |
| 票 068 §范围 5 | C | 平均 ≥ 25fps、下限 ≥ 20fps | 同 | `SPACEWALKER_MODE=tiangong`，**70 秒**，排除启动 5 秒 |

「60fps 是硬指标」出自 `docs/design/PRD-UI-v1.md` §0 的**现实约束**与 074 spec 的动效预算约束，
不是 NFR-01 的数值判据；`TiangongSession.swift` 里「NFR-01 要的是真机 60 秒」的注释同样与 PRD 的 30s 不符。
门禁请按上表判定，不要按「≥60fps」判。

**措辞不一致已统一回写（2026-11-16）**：`074-ui-chrome-v1.1-spec.md`（实现决策 9 与验收行）、
`docs/design/PRD-UI-v1.md` §1 现实约束行、`docs/design/DRAFT-v1.md` 实现对照节、
`079-14-screen-diff.md` 两处，均已改为「60fps 是体验目标，数值验收判据以 PRD NFR-01 为准」。
这是按 issue-tracker「以 PRD 为准并回写」做的机械同步，不是数值判据变更；
`TiangongSession.swift:499` 注释「真机 60 秒」与 PRD 30s 不符，已于同日改为「真机 30s 录屏」（仅注释，零行为变化）。

## 2. 设备与偏差

| 项 | 门禁基准 | 本次实际 |
| --- | --- | --- |
| 机型 | iPhone 16 Pro（iPhone17,1） | **iPhone 16 Pro（iPhone17,1）✓ 一致** |
| 系统 | iOS 26.6 | **iOS 27.0（24A437）✗ 不一致** |
| 连接 | 有线 | 有线，UDID `00008140-000A288836FB001C` |

`docs/PRD.md` §0 记载「v0.4 曾记 27.0，以门禁证据为准」，v0.10 把基准统一为 26.6。
**本次数据是 27.0 上的参考值，不能冒充 26.6 基准机型的门禁结论**；
是否接受等价机型、或需换机复测，由人裁决。

## 3. 可复现命令（已实测可用）

`tools/device.sh` 的三个坑，照抄即可避开：

1. `log` 只接受 `--interval / --once / --grep`，**不接受文件名**；输出走 stdout，要自己重定向。
2. `shot` 的参数是**完整输出路径**，记得带 `.png`。
3. `resolve_udid` 偶发解析不到有线设备（本次 11:59 出现过一次），显式设 `SPACEWALKER_UDID` 可绕过。

```bash
cd /Users/tango/Developments/SpaceWalker
export SPACEWALKER_UDID=00008140-000A288836FB001C

# 0) 必须用最新代码重编：build/ 里的旧包可能是几天前的
xcodebuild -project SpaceWalker.xcodeproj -scheme SpaceWalker \
  -destination 'generic/platform=iOS' -derivedDataPath build build \
  > /tmp/spacewalker-080-device-build.log 2>&1

# 1) B 阶段（星图）：device.sh run 默认 MODE=sky / FPS=1 / LAYERS=1
tools/device.sh run
sleep 45
tools/device.sh log --once > docs/gates/M3/080-device-perf-sky.log
tools/device.sh shot docs/gates/M3/080-device-sky.png

# 2) C 阶段（天宫）：run 写死 sky，且对已运行的进程再 launch 只会「重新激活」，
#    环境变量不生效 —— 必须先 terminate 真实 PID 再启动
xcrun devicectl device info processes --device "$SPACEWALKER_UDID" \
  --json-output /tmp/sw-procs.json >/dev/null 2>&1
PID=$(python3 -c "import json;d=json.load(open('/tmp/sw-procs.json'));print(next(p['processIdentifier'] for p in d['result']['runningProcesses'] if 'SpaceWalker.app/SpaceWalker' in str(p.get('executable',''))))")
xcrun devicectl device process terminate --device "$SPACEWALKER_UDID" --pid "$PID"
xcrun devicectl device process launch --device "$SPACEWALKER_UDID" \
  --environment-variables '{"SPACEWALKER_MODE":"tiangong","SPACEWALKER_FPS":"1"}' \
  com.tango.xingcha
sleep 75                       # 068 要 70 秒；前 5 秒启动期在统计里排除
tools/device.sh log --once > docs/gates/M3/080-device-perf-tiangong.log
tools/device.sh shot docs/gates/M3/080-device-tiangong.png
```

判据原文要求「30s 录屏 + 帧率统计」。
**2026-11-17 董事长裁决（A7）：以应用日志统计替代录屏**——`FrameRateSampler` 快照按 §4 口径
统计即为 NFR-01 正式取证，不再要求补录屏/Instruments。原「不能单独充当正式统计」注记就此废止；
§4 的口径警示（快照均值≠按帧加权均值、单帧 min 是保守下界）仍然有效，统计时照守。

## 4. 日志格式与统计口径（别把快照均值当 30 秒均值）

- `sky.perf` 每 5 秒一行，`tiangong.fps` / `probe.fps` 每 2 秒一行，只写 `Documents/session.log`，不上屏（076 后）。
- `FrameRateSampler(window: 120)` 是**滚动 120 帧窗口**：
  每行的 `avg` 是最近约 2 秒的帧率，`min` 是这 120 帧里最慢一帧的瞬时帧率。
  因此「样本均值的均值」只是近似，不是按帧加权的 30 秒平均；
  「全局最小瞬时」是保守下界，会被单帧卡顿（日志写入、系统调度）拉低。
- 提取示例：

```bash
grep 'sky.perf'      docs/gates/M3/080-device-perf-sky.log
grep 'tiangong.fps'  docs/gates/M3/080-device-perf-tiangong.log
grep 'thermal='      docs/gates/M3/080-device-perf-sky.log | grep -v 'thermal=nominal' || echo '全程 nominal'
```

## 5. 本次 agent 取数结果（原始数据在日志里，结论留空）

编译 `/tmp/spacewalker-080-device-build.log` → `BUILD SUCCEEDED`（签名 Apple Development: zhenzhi Tang）。
两段日志首行均为 `# iPhone17,1 | Version 27.0 (Build 24A437) | app 1.0(1) | bundle com.tango.spacewalker`。
（历史证据保留原样：2026-11-17 bundle id 已改为 `com.tango.xingcha`，本表数据取自旧 id 时期；旧 id 的 App 数据容器与新 id 不互通，重取证时日志从新容器取。）

| 阶段 | 证据 | 样本（排除启动 5s） | 覆盖 | `avg` 样本均值 | `avg` 最低 | `min` 全局最低 | `min<30` 快照 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| B 星图（五层全开） | `080-device-perf-sky.log`、`080-device-sky.png` | 33 条 | 5.7s → 170.9s | 59.67 | 55.4 | **6.6** | 5 / 33 (15%) |
| C 天宫（默认视图） | `080-device-perf-tiangong.log`、`080-device-tiangong.png` | 41 条 | 5.0s → 85.7s | 59.84 | 58.0 | **12.0** | 4 / 41 (10%) |

补充：10–40s 稳态 30s 窗口，B 阶段 `avg` 均值 58.93 / 最低瞬时 6.6；C 阶段 59.83 / 26.8。
两段日志 `thermal` 全程 `nominal`。

**两点已由董事长裁决（2026-11-17，见 `docs/design/2026-11-17-decisions.md` A4/A5）**：
1. **「下限」口径 = 30s 稳态窗口内 `avg` 快照的最低值**（窗口口径，非最慢单帧、非窗口均值）。
   理由：单帧 min 6.6/12.0 是 HUD 采样瞬时抖动（thermal 全程 nominal、avg 59–60），
   单帧口径在 iOS 不可达；窗口均值会藏掉 C 的 26.8 低谷。按此口径预判参考数据：
   B 最低 55.4 ≥ 30 ✓、C 最低 26.8 ≥ 20 ✓（avg 均值 B 58.93 ≥ 55 ✓、C 59.83 ≥ 25 ✓）。
   **最终达标判定与签字仍归人工，本注记不代判。**
2. **iOS 27.0 等价性：接受**（同硬件 iPhone17,1、同代际小版本、RealityKit 管线无破坏变更）。
   **附条件**：本表数据取自旧 bundle id + 081 删按钮前的代码，**不能直接转正**，
   仅作口径验证参考；转正须用 `com.tango.xingcha` 新包重取 B/C 两段（D5 真机接上后执行）。
   若可借到 26.6 设备优先补对照，借不到则接受 27.0 单组 + 上述条件。

截图同时复核了门禁项 5 的主界面：星图与天宫两屏均只见 44pt 只读状态条、
唯一暖金主操作、≤3 个上下文控件、3 个带文字 tab，**无 fps / pick / 坐标调试串**；
天宫默认态模型上 **0 个常驻标签**。长按 3 秒进诊断面板与 `SPACEWALKER_TG_*` 行为仍需真机人工复验。

## 5b. 新包重取（2026-11-17，D5 执行，com.tango.xingcha，判定仍归人）

A5 附条件兑现：旧 id App 已卸载（卸载前尝试备份 Documents 容器失败，
`ContainerLookupErrorDomain -1`，旧容器数据不可达；旧证据日志/截图已归档在 §5，无未归档数据损失），
`com.tango.xingcha` 新包全新安装启动，数据容器全新。

- 代码：HEAD `f6df7a6`（含 `764ee14` 死按钮删除、`4ebab45` 新 id、`ca9dc65` iPhone-only、`0c795e5` icon）。
- 包校验：`CFBundleIdentifier=com.tango.xingcha`、`UIDeviceFamily=[1]`、1.0(1)、
  `ITSAppUsesNonExemptEncryption=false`、签名 Apple Development: zhenzhi Tang（Team UKXWZ3FS84）。
- 设备：iPhone 16 Pro（iPhone17,1）✓ 基准机型一致；iOS 27.0（24A437）按 A5 接受；
  本次连接为 **localNetwork（无线）**，非有线——`device.sh` 用 `SPACEWALKER_UDID` 显式指定绕过 wired 过滤。
- 两段日志首行均为 `# iPhone17,1 | Version 27.0 (Build 24A437) | app 1.0(1) | bundle com.tango.xingcha`。
- 过程记录：第一次 B 段采集因**人为触屏操作**作废（22–27s 间星官层被图层面板关闭、
  54–56s 出现两次停留选中）；terminate 后重采，全程无操作。天宫段同样 terminate 真实 PID 后
  以 `MODE=tiangong` 全新启动（对已运行进程再 launch 环境变量不生效，见 §3 坑 2）。

| 阶段 | 证据 | 样本（排除启动 5s） | 覆盖 | `avg` 样本均值 | `avg` 最低 | `min` 全局最低 | `min<30` 快照 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| B 星图（LAYERS=1） | `080-device-perf-sky-xingcha.log`、`080-device-sky-xingcha.png` | 10 条 | 5.6s → 52.2s | 60.03 | **59.9** | 43.9 | 0 / 10 |
| C 天宫（默认视图） | `080-device-perf-tiangong-xingcha.log`、`080-device-tiangong-xingcha.png` | 41 条 | 5.2s → 85.3s | 60.00 | **60.0** | 43.5 | 0 / 41 |

补充：10–40s 稳态 30s 窗口，B 阶段 `avg` 均值 60.03 / 最低 59.9；C 阶段 60.00 / 60.0。
两段 `thermal` 全程 `nominal`；B 段 11 条快照图层标签全程 `line+outline+asterism` 无变化，
两段日志均无 `sky.dwell / sky.zoom / sky.mode / sky.group` 等操作事件（无操作取证成立）。

**按 A4 口径预判（不代判）**：B avg 均值 60.03 ≥ 55 ✓、窗口 avg 最低 59.9 ≥ 30 ✓；
C avg 均值 60.00 ≥ 25 ✓、窗口 avg 最低 60.0 ≥ 20 ✓。与旧包参考数据（B 55.4 / C 26.8 低谷）
相比本次全程贴 60fps 无低谷——差异可能来自新容器冷启动状态与无操作窗口，供人工判定时参考。

**两点口径事实（登记，不代裁）**：
1. `SPACEWALKER_LAYERS=1` 的会话标签受 feature flag 门控（`SkyView+Runtime.swift:51-52`：
   `showsAsterisms=cultureEnabled`、`showsPatterns=deepEnabled`），本机 `app.flags culture=1 deep=0`，
   故标签为 `line+outline+asterism`（星群层会话开关 off；场景实体已建：
   `sky.budget … asterism=814 pattern=98`）。旧包参考取证同为该标签，口径一致。
   「五层全开」若要求星群层会话开关也 on，需 `deepEnabled` 开关或代码支持，归人裁决。
2. PRD NFR-01 原文要求「30s 录屏 + 帧率统计」。**董事长已裁决（2026-11-17，A7）：
   以日志统计替代录屏**，本节快照统计即正式取证，录屏不再要求。剩余人工动作只有 §6 达标签字。

截图复核（门禁项 5 佐证，最终复验归 B5 人工）：星图屏状态条「姿态跟随 · 转动手机环顾」、
唯一暖金主操作「找星」、3 个上下文控件（图层/今夜/姿态）、3 个带文字 tab，无卡片无调试串；
天宫屏状态条「目标飞行器 · 1:20 展示」、主操作「开始拆解」、3 个上下文控件（剖面/工程图/再入）、
模型上 **0 个常驻标签**，无 fps/pick/坐标串（`tiangong.pick ok=4/5` 仅在日志，076 收敛生效）。

## 6. 人工结论（待填写）

- 执行日期：______ ｜ 执行人：______ ｜ 设备 / 系统：______
- 判据采用：☑ PRD NFR-01（A/B 55/30，C 25/20）（A4 裁决 2026-11-17） ☐ 其他（写明）____________
- 「下限」口径：☐ 最慢单帧 ☑ 30s 窗口统计 ☐ 百分位（P__） ☐ 其他 ________
  **口径细则（A4 裁决）：下限 = 稳态 30s 窗口内 `avg` 快照的最低值；avg 均值另须 ≥55/≥25。**
- 取证方式：☑ 日志统计替代录屏（A7 裁决 2026-11-17） ☐ 30s 录屏 / Instruments：____________
  证据路径：`080-device-perf-{sky,tiangong}-xingcha.log` + 同名 png（§5b，新包已取）
- B 阶段：☐ 达标 ☐ 不达标 ｜ C 阶段：☐ 达标 ☐ 不达标（§5b 新包数据按裁决口径预判均达标，签字归人）
- iOS 27.0 等价性：☑ 接受（附条件：新包重取后方可转正，见 §5 注记 2） ☐ 需换 26.6 基准机复测
- 门禁项 3 是否通过：☐ 是 ☐ 否 ｜ 签字：______
