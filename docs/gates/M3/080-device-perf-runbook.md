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

**未裁决的措辞不一致**：`080-human-gate.md`、`074-ui-chrome-v1.1-spec.md`、
`079-14-screen-diff.md` 仍写「60fps 硬指标」。是否统一回写，请人定；本次只改门禁清单与票 080 的判据行。

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
  com.tango.spacewalker
sleep 75                       # 068 要 70 秒；前 5 秒启动期在统计里排除
tools/device.sh log --once > docs/gates/M3/080-device-perf-tiangong.log
tools/device.sh shot docs/gates/M3/080-device-tiangong.png
```

判据要求「30s 录屏 + 帧率统计」，录屏与 Instruments 采样仍需人补；
应用自带日志只是 `FrameRateSampler` 的快照，**不能单独充当 NFR-01 的正式统计**（见 §4）。

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

| 阶段 | 证据 | 样本（排除启动 5s） | 覆盖 | `avg` 样本均值 | `avg` 最低 | `min` 全局最低 | `min<30` 快照 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| B 星图（五层全开） | `080-device-perf-sky.log`、`080-device-sky.png` | 33 条 | 5.7s → 170.9s | 59.67 | 55.4 | **6.6** | 5 / 33 (15%) |
| C 天宫（默认视图） | `080-device-perf-tiangong.log`、`080-device-tiangong.png` | 41 条 | 5.0s → 85.7s | 59.84 | 58.0 | **12.0** | 4 / 41 (10%) |

补充：10–40s 稳态 30s 窗口，B 阶段 `avg` 均值 58.93 / 最低瞬时 6.6；C 阶段 59.83 / 26.8。
两段日志 `thermal` 全程 `nominal`。

**必须人裁的两点**：
1. `min` 出现 6.6 / 12.0 这类单帧低谷。若把「下限 ≥30 / ≥20」理解为**最慢单帧**，两阶段都不达标；
   若按 PRD 的「30s 录屏帧率统计」取窗口统计，则 `avg` 稳定在 59–60。**口径由执行人写明后再判**。
2. 设备是 iOS 27.0，不是基准 26.6；本表只能作为参考数据。

截图同时复核了门禁项 5 的主界面：星图与天宫两屏均只见 44pt 只读状态条、
唯一暖金主操作、≤3 个上下文控件、3 个带文字 tab，**无 fps / pick / 坐标调试串**；
天宫默认态模型上 **0 个常驻标签**。长按 3 秒进诊断面板与 `SPACEWALKER_TG_*` 行为仍需真机人工复验。

## 6. 人工结论（待填写）

- 执行日期：______ ｜ 执行人：______ ｜ 设备 / 系统：______
- 判据采用：☐ PRD NFR-01（A/B 55/30，C 25/20） ☐ 其他（写明）____________
- 「下限」口径：☐ 最慢单帧 ☐ 30s 窗口统计 ☐ 百分位（P__） ☐ 其他 ________
- 30s 录屏 / Instruments 证据路径：____________________
- B 阶段：☐ 达标 ☐ 不达标 ｜ C 阶段：☐ 达标 ☐ 不达标
- iOS 27.0 等价性：☐ 接受 ☐ 需换 26.6 基准机复测
- 门禁项 3 是否通过：☐ 是 ☐ 否 ｜ 签字：______
