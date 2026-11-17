# 080 人工门禁检查清单（待人工执行）

日期：2026-11-15（12:05 更新）｜ 状态：**未通过 / 待人工判定** ｜ 关联：068 欠账、074 父 spec、076–079 实现票

agent 已完成的实现与取证：`076`（诊断开关唯一来源）、`077`（底部三段 + 只读状态条）、`078`（选中派生标签与信息卡）、`079`（token、双主题、14 屏对照）。全量单测 **388 项、0 失败**。以下五项只能由人判定，**agent 不代判、不宣告通过**。

证据链补记（2026-11-15 10:31）：`079-final.log`（10:07）与 `079-contrast.log`（10:09）之后仍有 `ChromeLayout.swift` 的 10:11 改动（亮色卡片与主题切换入口），两条日志都早于最终代码。为消除时间差，在已提交的 `c00819e` 上重跑全量单测：`/tmp/spacewalker-080-verify.log` → **388 项、0 失败、`TEST SUCCEEDED`**，工作区干净。门禁复核以这条为准。

证据链更新（2026-11-17，A8 后）：董事长裁决「不再等约人签体验，按既定开始」（A8），
081 舱内标注 / 083 今夜反馈 / 084 F1–F4 已实施（`06d2234`）。全量单测基线更新为
**412 项、0 失败**（/tmp/spacewalker-084-green2.log），另有 ChromeFeedbackUITests 4 条
UI 验收通过（/tmp/spacewalker-084-ui3.log）。**人工取证请以含 `06d2234` 的包为准**；
B3 帧率数据已于 20:20 在最终包 06d2234 同源重采（runbook **§5c**：B 60.04/59.9、C 60.00/60.0，
thermal 全 nominal，与 §5b 一致），**签字以 §5c 为准，与上架 IPA 完全同源**。080 人工项不因实施而代判。

证据链更新（2026-11-16，081 后）：本批之后有 4 个新提交——帧率判据措辞统一回写（`22b328d`）、NFR-01 注释修正（`d5219a0`）、076 措辞收敛（`d2ad176`）、**死按钮删除（`764ee14`，行为变化：剖面/对接底部各少 1 个无动作控件）**，及文档回改（`e1f3870`）。全量单测基线更新为 **390 项、0 失败**（`/tmp/spacewalker-081-deadbuttons-green.log`，含 764ee14 代码）。081 对抗验证截图 `081-cutaway-no-interior-labels.png` / `081-docking-no-hold.png`。**人工取证请以含 `764ee14` 的包为准**；既有 `080-device-*.png` 取的是星图/天宫默认态，不含这两个控件，仍有效。

## 门禁项

| # | 判据 | 执行人 | 证据路径 | 状态 |
| --- | --- | --- | --- | --- |
| 1 | 5 名未见过本产品的新用户，10 秒内 ≥4/5 能说出「看星星 + 拆飞船」；**同场加测 X-07/X-08（A6 裁决 2026-11-17）**：看三视角图认出天宫一号 ≥4/5、细节 1–5 分均值 ≥3 | 人（盲测） | `080-blindtest-notes.md` Part A + Part B + 5 份录音/笔记 | 待人工 |
| 2 | 盲测给出「标签选中才显示」的降级结论：保持降级 / 恢复常驻，并写明理由 | 人（盲测结论） | `080-blindtest-notes.md` Part C | 待人工 |
| 3 | **PRD NFR-01**：A/B 平均 ≥55fps、下限 ≥30fps；C 平均 ≥25fps、下限 ≥20fps；基准机型 iPhone 16 Pro / iOS 26.6，取证方式按 A7 裁决以日志统计替代录屏；票 068 另要 C 阶段 70 秒（排除启动 5 秒） | 人（真机） | `080-device-perf-runbook.md` §5b、`080-device-perf-{sky,tiangong}-xingcha.log`、`080-device-*-xingcha.png` | **取证已闭环（2026-11-17 D5+A7）**：新包无操作重采 B avg 60.03/窗口最低 59.9、C 60.00/60.0，thermal 全程 nominal，按 A4 口径预判均达标；**仅剩 §6 人工签字** |
| 4 | 稿与实现逐项复核，差异归零或全部登记为「设计意图、非验收项」 | 人（设计裁决） | `079-14-screen-diff.md` 的处置列逐条签字 | 待人工 |
| 5 | 076 开关收敛复核：主界面 0 处 fps/pick/坐标串；长按状态条标题 3 秒进诊断面板；既有 `SPACEWALKER_TG_*` 取证开关行为不变 | 人（开发复核） | `080-agent-verification.txt` §6（2026-11-17 新包预取证）、`080-device-{sky,tiangong,diagnostics}-xingcha.png` | **agent 预取证已闭环**：零调试串截图 ×2、诊断面板 DIAGNOSTICS=1 截图、13 个 TG_* 开关清单与 11-15 一致；**仅剩「长按 3s 手势」人工复验**（真机已恢复星图默认态待验） |

> 门禁项 3 原写「iPhone 16 / iOS 26.6、60 秒平均 ≥60fps」，机型与阈值都与 PRD 不符，已按 PRD NFR-01 回写；
> 详见 `080-device-perf-runbook.md` §1。

## 取证命令（沿用项目惯例）

**完整可复现命令见 `080-device-perf-runbook.md` §3**，下面只列最小集。
原清单里的 `tools/device.sh log 080-device-perf.log` 是错的（`log` 不接受文件名，会报「未知参数」），
`shot 080-device-sky` 也会生成无扩展名文件；两处均已修正。

```bash
export SPACEWALKER_UDID=00008140-000A288836FB001C   # resolve_udid 偶发失败，显式指定更稳
tools/device.sh run                                  # 默认 MODE=sky / FPS=1 / LAYERS=1
tools/device.sh log --once > docs/gates/M3/080-device-perf-sky.log
tools/device.sh shot docs/gates/M3/080-device-sky.png

# 真机 / 模拟器无头取证开关（本批新增）
SPACEWALKER_THEME=light                 # 亮色主题
SPACEWALKER_DIAGNOSTICS=1              # 启动即开诊断面板
SPACEWALKER_TG_SELECT=lab              # 启动即选中实验舱
SPACEWALKER_TG_SEPARATED=lab           # 启动即分离实验舱

# 复验全量单测
xcodebuild test -scheme SpaceWalker -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

帧率判据以 PRD NFR-01 为准（A/B 55/30、C 25/20，30s 录屏 + 帧率统计）。
`sky.perf` / `tiangong.fps` 只写日志不上屏（076 之后主界面零调试串），且每行是滚动 120 帧快照，
**不能单独充当 NFR-01 的正式 30s 统计**；录屏与 Instruments 采样仍需人补。

## 068 欠账映射

| 068 原欠账 | 本批承接情况 |
| --- | --- |
| 5 人盲测 ≥4/5 | 未执行 → 门禁项 1（UI PRD v1 的「10 秒说清产品」定位盲测） |
| 标签降级等盲测结论 | 078 已把「常驻 → 选中才显示」实现并取证（`078-C1-zero-labels.png` / `078-C2-separated.png`），**结论仍由盲测给** → 门禁项 2 |
| 真机帧率复测 | **agent 已在 iOS 27.0 真机取参考数据**（见下），基准 26.6 机型与人工判定仍欠 → 门禁项 3 |
| **X-07 辨识度盲测 ≥4/5 / X-08 细节评分 ≥3** | **A6 裁决（2026-11-17）：纳入 080，不另开票、不豁免**。与门禁项 1 同场执行（同一份问卷加两题，不拆场）：Part B 看三视角图认出天宫一号 ≥4/5、细节 1–5 分均值 ≥3。已并入门禁项 1 判据 |

## 关闭条件

五项全部由人签字通过后，把结论写入本文件下方「人工结论」节，附截图与日志，再关闭 080 与 074 父 spec。任何一项未通过或证据缺失，074 保持 `ready-for-agent`，不得宣告 UI v1.1 交付完成。
另需先裁决 068 的 X-07 / X-08 漏项（纳入 080 / 另开票 / 明确豁免）；PRD §11.2 写明「M3.1 不过，不进 1.0 内容冻结」。

## agent 侧补取证（2026-11-15 12:05，不代判）

真机 **iPhone 16 Pro / iOS 27.0 (24A437)** 已连接；重新编译真机包（旧包停在 11/08，早于 075–079），
装包启动后取到两段 runtime log 与两张截图。全部原始证据归档 `docs/gates/M3/`：

| 文件 | 内容 |
| --- | --- |
| `080-device-perf-sky.log` / `080-device-sky.png` | B 阶段星图五层全开，263 行日志 / 34 条 `sky.perf`，覆盖 170.9s |
| `080-device-perf-tiangong.log` / `080-device-tiangong.png` | C 阶段天宫默认视图，71 行日志 / 43 条 `tiangong.fps`，覆盖 85.7s |
| `080-device-perf-runbook.md` | 判据纠错、设备偏差、可复现命令、统计口径、待填结论表 |
| `080-agent-verification.txt` | 最终 HEAD 上重跑「主界面零调试串 / 长按 3 秒 / 开关清单」静态复核 |
| `080-blindtest-notes.md` | 定位盲测 / 辨识度盲测 / 标签降级结论的空白记录模板 |

取数（排除启动 5 秒）：B 阶段 `avg` 样本均值 **59.67**、最低 `avg` 55.4、全局最低瞬时 **6.6**，`min<30` 5/33；
C 阶段 **59.84** / 58.0 / **12.0**，`min<30` 4/41；两段 `thermal` 全程 `nominal`。
截图确认两屏主界面无 fps / pick / 坐标调试串，天宫默认态 0 个常驻标签。

**agent 不判定达标**，以下三点必须由人写明后再签：
1. 「下限」口径：按最慢单帧（则两阶段都不达标）还是按 30s 窗口统计（则 `avg` 稳定 59–60）。
2. iOS 27.0 与基准 26.6 的等价性：接受 / 换机复测。
3. PRD 要求的 **30s 录屏 + Instruments 帧率统计**尚未做，应用自带日志只是滚动窗口快照。

另在静态复核里发现两处措辞问题（详见 `080-agent-verification.txt` §4）：
`tools/device.sh` 的两条错误命令已修正；076 证据里「`LaunchMode.environment()` 是唯一读取 `ProcessInfo` 的入口」
不字面成立（HEAD 仍有 48 处，2 处绕过 helper），不影响门禁项 5 的「既有 `SPACEWALKER_TG_*` 行为不变」判定，但措辞需收敛。

## 人工结论

（待填写：日期、执行人、逐项结论、证据链接、是否通过）
