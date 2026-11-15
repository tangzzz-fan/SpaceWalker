# 080 人工门禁检查清单（待人工执行）

日期：2026-11-15 ｜ 状态：**未通过 / 待人工判定** ｜ 关联：068 欠账、074 父 spec、076–079 实现票

agent 已完成的实现与取证：`076`（诊断开关唯一来源）、`077`（底部三段 + 只读状态条）、`078`（选中派生标签与信息卡）、`079`（token、双主题、14 屏对照）。全量单测 **388 项、0 失败**（`/tmp/spacewalker-079-final.log`）。以下五项只能由人判定，**agent 不代判、不宣告通过**。

## 门禁项

| # | 判据 | 执行人 | 证据路径 | 状态 |
| --- | --- | --- | --- | --- |
| 1 | 5 名未见过本产品的新用户，10 秒内 ≥4/5 能说出「看星星 + 拆飞船」 | 人（盲测） | `docs/gates/M3/080-blindtest-notes.md` + 5 份录音/笔记 | 待人工 |
| 2 | 盲测给出「标签选中才显示」的降级结论：保持降级 / 恢复常驻，并写明理由 | 人（盲测结论） | 同上，单列一节 | 待人工 |
| 3 | 基准机型 iPhone 16 / iOS 26.6 真机 60fps 硬指标达标，留 runtime log（60 秒平均与下限） | 人（真机） | `docs/gates/M3/080-device-perf.log`、`080-device-*.png` | 待人工 |
| 4 | 稿与实现逐项复核，差异归零或全部登记为「设计意图、非验收项」 | 人（设计裁决） | `079-14-screen-diff.md` 的处置列逐条签字 | 待人工 |
| 5 | 076 开关收敛复核：主界面 0 处 fps/pick/坐标串；长按状态条标题 3 秒进诊断面板；既有 `SPACEWALKER_TG_*` 取证开关行为不变 | 人（开发复核） | `076-default.png` / `076-debug-switches-on.png` / `076-diagnostics-panel.png` + 真机复验记录 | 待人工 |

## 取证命令（沿用项目惯例）

```bash
# 真机安装与截图 / 日志
tools/device.sh run
tools/device.sh shot 080-device-sky
tools/device.sh log 080-device-perf.log

# 真机 / 模拟器无头取证开关（本批新增）
SPACEWALKER_THEME=light                 # 亮色主题
SPACEWALKER_DIAGNOSTICS=1              # 启动即开诊断面板
SPACEWALKER_TG_SELECT=lab              # 启动即选中实验舱
SPACEWALKER_TG_SEPARATED=lab           # 启动即分离实验舱

# 复验全量单测
xcodebuild test -scheme SpaceWalker -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

帧率判据沿用 NFR-01：60 秒平均 ≥60fps、下限不掉出预算；`sky.perf` / `tiangong.logFrameRate` 只写日志不上屏（076 之后主界面零调试串），所以真机数据要从 `tools/device.sh log` 或诊断面板的运行日志里取。

## 068 欠账映射

| 068 原欠账 | 本批承接情况 |
| --- | --- |
| 5 人盲测 ≥4/5 | 未执行 → 门禁项 1 |
| 标签降级等盲测结论 | 078 已把「常驻 → 选中才显示」实现并取证（`078-C1-zero-labels.png` / `078-C2-separated.png`），**结论仍由盲测给** → 门禁项 2 |
| 真机帧率复测 | 未执行 → 门禁项 3 |

## 关闭条件

五项全部由人签字通过后，把结论写入本文件下方「人工结论」节，附截图与日志，再关闭 080 与 074 父 spec。任何一项未通过或证据缺失，074 保持 `ready-for-agent`，不得宣告 UI v1.1 交付完成。

## 人工结论

（待填写：日期、执行人、逐项结论、证据链接、是否通过）
