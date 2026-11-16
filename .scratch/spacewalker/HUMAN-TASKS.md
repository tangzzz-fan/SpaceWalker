# 星槎 1.0 人工任务汇总表

> 生成：2026-11-17（票 082 收尾）｜ 维护约定：完成一项勾一项，附证据路径；agent 不代判任何「裁决」项。
> 顺序建议：先 A（裁决类，阻塞后续）→ B（080 门禁）→ C（上架执行）。D 为 agent 待命项，人确认即触发。
>
> **2026-11-17 更新：董事长已批「按拟定执行」，七项裁决全部生效（见
> `docs/design/2026-11-17-decisions.md`）。A 组裁决已全部落地（A2 改配回归、A3–A6 文档回填）；
> 当前唯一阻塞 = B 组 080 人工门禁（需真机 + 5 人盲测）。080 签字后 D3/D6 自动触发。**

## A. 裁决类（董事长，均阻塞下游）

| # | 任务 | 实现步骤 | 产出/落点 | 阻塞 |
|---|---|---|---|---|
| A1 | ~~icon 稿确认~~ **已裁决（2026-11-17）：采用 A 稿「星与槎合一」**；D1 已实施接入工程 | — | 082 票已记录 | — |
| A2 | ~~iPad 裁决~~ **已裁决+已实施：iPhone-only**。`TARGETED_DEVICE_FAMILY="1"`（主+两测试 target，pbxproj 8 处全 1）；390 项 0 失败；真机包 UIDeviceFamily=[1]；PRD-UI 平台行回写（横屏=043 既有能力非漂移） | — | project.yml / PRD-UI / APPSTORE 已改 | — |
| A3 | ~~定价裁决~~ **已裁决：免费、无内购、无广告**（Pro 化 2.0 再议） | — | APPSTORE §2 价格行 + §8 已回填 | — |
| A4 | ~~下限口径~~ **已裁决：30s 稳态窗口 avg 快照最低值**（非单帧、非均值）。参考数据预判 B 55.4≥30 ✓ C 26.8≥20 ✓；**达标签字仍归人** | — | runbook §5 注记 + §6 勾选已回填 | — |
| A5 | ~~iOS 27 等价~~ **已裁决：接受，附条件**——旧 id+旧代码数据不能直接转正，须 com.tango.xingcha 新包重取（D5） | — | runbook §5 注记 2 + §6 勾选已回填 | — |
| A6 | ~~068 漏项~~ **已裁决：X-07/X-08 并入 080 门禁项 1 同场盲测**（问卷加两题，不拆场不豁免） | — | 080 checklist 门禁项 1 + Part B + 068 票已更新 | — |

## B. 080 人工门禁（五项，PRD §11.2：M3.1 不过不进 1.0 内容冻结）

前置：真机接数据线（当前断连）；用含 `764ee14`（死按钮删除）与 `4ebab45`（新 bundle id）的包；
**新 id 数据容器不互通，须全新启动**；旧「星槎」App 建议手动删除。装包：`tools/device.sh run --build`。

| # | 任务 | 实现步骤 | 产出/落点 |
|---|---|---|---|
| B1 | 定位盲测 ≥4/5 **+ X-07/X-08（A6 并入）** | 找 5 名未见过产品的新用户，各看首屏 10 秒问「这是做什么的」（≥4 人说出「看星星+拆飞船」）；**同场**再看三视角图问「认出什么」（X-07 ≥4/5）+「细不细」1–5 分（X-08 均值 ≥3）。逐人记录原话 | `080-blindtest-notes.md` Part A + Part B + 5 份笔记/录音 |
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
| C4 | 截图挑选上传 | 080 过后跑 `tools/appstore-screenshots.sh`（6 画面自动采集到 `docs/design/appstore-screenshots/`）；人工核对构图/挑选/排序，可选加文案框；**A2 已裁 iPhone-only，无需 iPad 截图**；上传 ASC | ASC 截图（6.9" 竖屏） |
| C5 | Archive 上传 | Xcode → Any iOS Device → Product Archive → Distribute（Apple Distribution 自动签名已配好，Team UKXWZ3FS84）；或 fastlane。版本号 1.0(1) 已在 Info.plist | ASC 构建版本 |
| C6 | 提交审核 | 勾选构建版本 + 出口合规（已预答 NO，不弹问卷）+ 版权 `2026 Tang`；提交；被拒按意见回票 | 审核状态 |

## D. agent 待命项（人确认即触发，不需人工动手）

| # | 任务 | 触发条件 |
|---|---|---|
| D1 | ~~icon 接入~~ **已完成**：`Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`（无 alpha），构建产物校验见 082 票 | — |
| D2 | ~~iPad 改配~~ **已完成**（A2 实施：`"1"` + 390 项回归 + 真机 UIDeviceFamily=[1]） | — |
| D3 | 081 舱内标注：**方案已批（常显/11pt/080 后）**，按 proposal.md TDD 实现 + VoiceOver + 重截 C5 | **080 人工门禁签字后**触发 |
| D4 | ~~286 笔误回写~~ **已完成**（2026-11-17，PRD-UI §1 已改 288 并注出处） | — |
| D5 | 真机接上后：代删旧 id App、装新包、代跑 B3 采集（判定仍归人） | 真机接数据线 |
| D6 | 083 今夜反馈：**方案已批（方案二最小反馈）**，TDD 接 isSelected+statusText + 重拍截图第 3 张 + 079-diff A5 更新 | **080 人工门禁签字后**触发 |

## 已完成（agent，2026-11-17，票 082）

- bundle id → `com.tango.xingcha`（4ebab45，390 项单测 0 失败，真机包签名验证）
- 死按钮删除 + 稿实现双向回改（764ee14 等 6 提交，081 票）
- `ITSAppUsesNonExemptEncryption=false`（390 项单测 0 失败）
- APPSTORE.md 填写信息全集 + 截图脚本 + icon brief 与 open-design 出稿