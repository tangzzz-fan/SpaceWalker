# 星槎 1.0 人工任务汇总表

> 生成：2026-11-17（票 082 收尾）｜ 维护约定：完成一项勾一项，附证据路径；agent 不代判任何「裁决」项。
> 顺序建议：先 A（裁决类，阻塞后续）→ B（080 门禁）→ C（上架执行）。D 为 agent 待命项，人确认即触发。

## A. 裁决类（董事长，均阻塞下游）

| # | 任务 | 实现步骤 | 产出/落点 | 阻塞 |
|---|---|---|---|---|
| A1 | ~~icon 稿确认~~ **已裁决（2026-11-17）：采用 A 稿「星与槎合一」**；D1 已实施接入工程 | — | 082 票已记录 | — |
| A2 | **iPad 支持裁决** | 现工程 `TARGETED_DEVICE_FAMILY="1,2"` 含 iPad，与 PRD-UI「仅 iPhone」矛盾（082 票登记）。选 iPhone-only → agent 改 `"1"` + 全量回归 + ASC 无需 iPad 截图；选保留 → PRD-UI 回写 + 需补 iPad 截图与版式验收 | project.yml 或 PRD-UI 回写 | C4 |
| A3 | **定价裁决** | PRD 无定价条目。建议 1.0 免费无内购（快速过审攒评价）；若付费需定价格档与是否内购 | APPSTORE.md §8.3 回填 | C2 |
| A4 | **「下限」口径** | 080 runbook §5 勾选：最慢单帧 / 30s 窗口统计 / 百分位 P__ / 其他。agent 参考数据：快照均值 59–60，最慢单帧口径会显著低于窗口口径 | runbook §5 勾选行 | B3 |
| A5 | **iOS 27.0 等价性** | 参考数据取自 iPhone 16 Pro / iOS 27.0（24A437），基准是 26.6。接受等价 → 参考数据可转正；不接受 → 需 26.6 真机复测 | runbook §5 勾选行 | B3 |
| A6 | **068 X-07/X-08 漏项** | 「看三视角图认出天宫一号」盲测 ≥4/5（X-07）与细节评分 ≥3（X-08）：纳入 080 / 另开票 / 明确豁免，三选一 | 080 checklist 或新票 | B1 |

## B. 080 人工门禁（五项，PRD §11.2：M3.1 不过不进 1.0 内容冻结）

前置：真机接数据线（当前断连）；用含 `764ee14`（死按钮删除）与 `4ebab45`（新 bundle id）的包；
**新 id 数据容器不互通，须全新启动**；旧「星槎」App 建议手动删除。装包：`tools/device.sh run --build`。

| # | 任务 | 实现步骤 | 产出/落点 |
|---|---|---|---|
| B1 | 定位盲测 ≥4/5 | 找 5 名未见过产品的新用户，各看首屏 10 秒，问「这是做什么的」；≥4 人说出「看星星+拆飞船」即过。逐人记录原话 | `080-blindtest-notes.md` Part A + 5 份笔记/录音 |
| B2 | 标签降级结论 | 同一批盲测观察「标签选中才显示」是否造成困惑；裁决保持降级/恢复常驻并写理由 | Part C 结论行 |
| B3 | 真机帧率（NFR-01） | 按 `080-device-perf-runbook.md`：星图全图层 30s 录屏 + 天宫 C 阶段 70s（排除启动 5s）；`tools/device.sh log` 收日志；统计口径按 A4 裁决执行；判据 A/B 平均≥55 下限≥30、C 平均≥25 下限≥20 | `080-device-perf-{sky,tiangong}.log` + 录屏 + 统计表 |
| B4 | 稿实现同源签字 | 逐条过 `079-14-screen-diff.md` 处置列（14 屏，C5 已降「部分」）；差异归零或登记「设计意图、非验收项」；081 舱内标注若已实现需重截 C5 | diff 表逐条签字 |
| B5 | 076 开关收敛复核 | 真机最终 HEAD：主界面 0 处 fps/pick/坐标串；长按状态条标题 3s 进诊断面板；`SPACEWALKER_TG_*` 取证开关行为不变；对照 `080-agent-verification.txt` | 真机复验记录 + 新截图 |

## C. 上架执行（人工，ASC/开发者账号操作）

| # | 任务 | 实现步骤 | 产出/落点 |
|---|---|---|---|
| C1 | 注册 Bundle ID + 建 App | developer.apple.com → Certificates,IDs → 注册 `com.tango.xingcha`；ASC → 我的 App → ＋，按 `docs/design/APPSTORE.md` §1 填 | ASC App 记录 |
| C2 | 填写元数据 | 照抄 APPSTORE.md §2–§5：名称/副标题/类别/描述/关键词/宣传文本/隐私问卷（不收集数据）/审核备注/联系人；定价按 A3 | ASC 版本页 |
| C3 | 隐私政策页 | 用 APPSTORE.md §4 建议文本做一页静态页（GitHub Pages 等），填联系邮箱，URL 入 ASC | 隐私政策 URL |
| C4 | 截图挑选上传 | 080 过后跑 `tools/appstore-screenshots.sh`（6 画面自动采集到 `docs/design/appstore-screenshots/`）；人工核对构图/挑选/排序，可选加文案框；按 A2 裁决决定是否需要 iPad 截图；上传 ASC | ASC 截图（6.9" 竖屏） |
| C5 | Archive 上传 | Xcode → Any iOS Device → Product Archive → Distribute（Apple Distribution 自动签名已配好，Team UKXWZ3FS84）；或 fastlane。版本号 1.0(1) 已在 Info.plist | ASC 构建版本 |
| C6 | 提交审核 | 勾选构建版本 + 出口合规（已预答 NO，不弹问卷）+ 版权 `2026 Tang`；提交；被拒按意见回票 | 审核状态 |

## D. agent 待命项（人确认即触发，不需人工动手）

| # | 任务 | 触发条件 |
|---|---|---|
| D1 | ~~icon 接入~~ **已完成**：`Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`（无 alpha），构建产物校验见 082 票 | — |
| D2 | iPad 边界改 `"1"` + 全量回归（或 PRD-UI 回写） | A2 裁决 |
| D3 | 081 舱内标注：先出稿（三处标注+1px 引线，SwiftUI overlay）→ 确认 → TDD 实现 + VoiceOver | 董事长点头开工（081 票 ready-for-agent） |
| D4 | ~~286 笔误回写~~ **已完成**（2026-11-17，PRD-UI §1 已改 288 并注出处） | — |
| D5 | 真机接上后：代删旧 id App、装新包、代跑 B3 采集（判定仍归人） | 真机接数据线 |
| D6 | 083 今夜对齐 chrome 缺口：先出稿（方案一贴稿 / 方案二最小反馈）→ 确认 → 实现 + 重拍截图第 3 张 | 董事长选方案；实现须 080 过后或明示插队 |

## 已完成（agent，2026-11-17，票 082）

- bundle id → `com.tango.xingcha`（4ebab45，390 项单测 0 失败，真机包签名验证）
- 死按钮删除 + 稿实现双向回改（764ee14 等 6 提交，081 票）
- `ITSAppUsesNonExemptEncryption=false`（390 项单测 0 失败）
- APPSTORE.md 填写信息全集 + 截图脚本 + icon brief 与 open-design 出稿