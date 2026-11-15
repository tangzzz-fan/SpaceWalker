---
id: 080
title: 人工门禁：盲测、真机帧率与稿实现同源复核
status: ready-for-human
stage: M3
blocked_by: [077, 078, 079]
---

## 背景

承接 068 欠下的人工门禁：新用户能否 10 秒说清产品、标签降级是否可接受、真机帧率（PRD NFR-01）是否守住，以及稿与实现是否仍同源。这些只能由人判定，agent 不得自行宣告通过。

> 判据纠错（2026-11-15）：本票原写「60fps 硬指标」「iPhone 16 / iOS 26.6」，与 `docs/PRD.md`
> NFR-01（A/B 平均 ≥55fps、下限 ≥30fps；C ≥25/20；基准 iPhone 16 Pro / iOS 26.6；30s 录屏）
> 不符。按 `docs/agents/issue-tracker.md`「issue 与 PRD 冲突时以 PRD 为准并回写 issue」，
> 以 PRD 为准；详见 `docs/gates/M3/080-device-perf-runbook.md` §1。

父 spec：074。

## 验收标准

- [ ] 5 人盲测 ≥4/5 能说出「看星星 + 拆飞船」
- [ ] 盲测给出「标签选中才显示」的降级结论（保持降级 / 恢复常驻）
- [ ] 基准机型 iPhone 16 Pro / iOS 26.6 真机帧率复测：PRD NFR-01 的 A/B 平均 ≥55fps、下限 ≥30fps；C 平均 ≥25fps、下限 ≥20fps；30s 录屏 + 帧率统计并留 runtime log（票 068 另要 C 阶段 70 秒、排除启动 5 秒）
- [ ] 稿与实现逐项复核，差异归零
- [ ] 门禁结论写入 `docs/gates/M3/`，附截图与日志

## 测试缝

人工。证据路径与命名沿用 `docs/gates/` 既有惯例、`tools/device.sh log|shot|run`。

## 备注

- `status: ready-for-human`：真机与盲测不得由 agent 判定通过。
- 依赖 077 / 078 / 079 全部完成；076 的开关收敛也要一并在同源复核里确认。
- 门禁通过后 074 父 spec 才可关闭。
- **068 欠账漏项待裁决**：068 / X-07 的辨识度盲测（不看标签认出天宫一号 ≥4/5）与 X-08 细节评分（均值 ≥3）与门禁项 1 的「10 秒说清产品」不是同一件事，原映射把它们合并了。记录位已备在 `080-blindtest-notes.md` Part B；纳不纳入 080 由董事长定，PRD §11.2「M3.1 不过，不进 1.0 内容冻结」。

## agent 准备记录（2026-11-15，不代判）

依赖 077 / 078 / 079 已实现并提交；076 的开关收敛在 `079-14-screen-diff.md` 与 `080-human-gate-checklist.md` 门禁项 5 里留了复核位。

已交付 `docs/gates/M3/080-human-gate-checklist.md`：5 项判据、执行人、证据路径、取证命令、068 欠账映射、074 关闭条件与待填的「人工结论」节。

agent 侧可用的实现证据：全量单测 388 项 0 失败；`076` 三张调试开关对照图（默认与全开 MD5 一致）、`077` 三点按对抗验证、`078` 下滑关闭坐标拖拽验证与五类模式不回归截图、`079` 深浅双主题 7 张截图与 14 屏对照清单。

**12:05 补取证（仍不代判）**：真机 iPhone 16 Pro / **iOS 27.0**（与基准 26.6 不符）已连接，重新编译真机包并取到
`080-device-perf-{sky,tiangong}.log` 与两张 `080-device-*.png`；B 阶段 `avg` 样本均值 59.67、最低瞬时 6.6；
C 阶段 59.84、最低瞬时 12.0，`thermal` 全程 nominal。另在最终 HEAD 重跑门禁项 5 的静态复核
（`080-agent-verification.txt`），并交付 `080-device-perf-runbook.md`（判据纠错 + 可复现命令）、
`080-blindtest-notes.md`（空白记录模板）。`080-human-gate-checklist.md` 已同步纠错与证据链。

**未执行、也不得由 agent 宣告通过**：5 人盲测、标签降级体验结论、基准 iOS 26.6 机型复测与 30s 录屏帧率统计、
下限口径与机型等价性裁决、稿实现同源的人工签字。本票维持 `status: ready-for-human`。
