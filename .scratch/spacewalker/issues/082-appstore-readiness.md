---
id: 082
title: 上架准备：app icon、图标资源、ASC 填写信息、截图脚本
status: ready-for-human
stage: M3.1
blocked_by: [080]
---

## 背景

董事长指令（2026-11-17）：① open-design 出 app icon 与上架图标资源，形成上架填写信息；
② 收尾 agent 可做工作，人工任务形成汇总表。工程此前无任何 .xcassets / AppIcon（默认白图标）。

## 范围与产物

- [x] brief 落盘：`docs/design/2026-11-17-app-icon/brief.md`（色彩 token、红线、1024 规格、语义候选 A/B/C）
- [x] open-design 项目 `xingcha-app-icon` 出稿（byok-opencode / deepseek-v4-pro；AMR 未登录，走 Keychain BYOK）
  - 产物：`icon.svg`（A 星与槎合一）+ `icon-b.svg`（B 三垣环抱）+ `index.html` 展示板；
    归档副本与 qlmanage 渲染预览（1024 + 180/120/80/60/40）在 `docs/design/2026-11-17-app-icon/`
  - 已核：两稿满幅深空底 #05070D→#0C1018、暖金 #E8B15C 系、冷青 #6FA8C8、无文字无滤镜；
    A 稿 40px 预览船形+星仍可辨（人工复核为准）
  - 过程记录：首轮 run 因 HTTP 字段误用 `prompt`（应为 `message`）空转；次轮模型只出计划即退；
    第三轮续跑期间出现过一版违规稿（紫青星云、错字「星茶」），被合规重写覆盖，终稿已逐行核验无残留
- [ ] **icon 稿董事长确认**（展示板 `index.html`，A 主稿 + B 对比稿 + 40pt 可辨性预览）
- [ ] 确认后 agent 导出 1024 PNG（无 alpha）→ `Sources/Assets.xcassets/AppIcon.appiconset`（universal 单尺寸）→ xcodegen → 构建产物校验
- [x] ASC 填写信息：`docs/design/APPSTORE.md`（名称/副标题/描述/关键词/隐私问卷/审核备注/素材署名，数字已对源码核实 2996/288/301/88）
- [x] 出口合规：`ITSAppUsesNonExemptEncryption=false` 入 project.yml（纯离线，无自有加密）
- [x] 截图采集脚本：`tools/appstore-screenshots.sh`（Pro Max 模拟器 6 画面无头启动，simctl 直出，归档 `docs/design/appstore-screenshots/`）
  - 已实跑：6 张全部 **1320×2868**（ASC 6.9" 规格），逐张目检通过
  - 第 2 张改用 `LAYERS=1 NOCONST=1`（`ASTERISMS=1` 实为 060 票目录直开开关，会弹列表）
  - 第 5 张补 `TG_SELECT=lab`（无选中态时主操作仍「开始拆解」，与分离画面矛盾）
  - 第 3 张今夜态拍不出差异 → 查实 **083 缺口**（tonight mode 不可达，chrome 死分支），暂用默认态顶位
- [x] 人工任务汇总表：`.scratch/spacewalker/HUMAN-TASKS.md`

## 事实核查记录（2026-11-17）

- 位置：`kCLLocationAccuracyThreeKilometers` 粗精度、仅本机；全仓无 URLSession/网络代码 → ASC 隐私问卷「不收集数据」成立
- 星官 301（asterisms.json 实数）、恒星 2996、可选中 288（PRD v0.6.1；PRD-UI 写 286 为笔误，以 PRD 为准）
- 素材：HYG v4.1 与 Stellarium chinese 均 CC BY-SA（署名+同许可分发，应用内面板已声明）；银河图 NASA SVS 公共域

## 发现的漂移（登记，不擅改）

- **iPad 支持矛盾**：`TARGETED_DEVICE_FAMILY="1,2"`（iPhone+iPad）vs PRD-UI-v1「仅 iPhone」/074「不做 iPad 版式」。
  横屏是 043 票有意实现（星图看全大星座），不算漂移；iPad 从未有票。处置见 HUMAN-TASKS #4，请董事长裁决。
- PRD-UI-v1 §1「286 颗可点选」与 PRD v0.6.1「288」不一致——已回写为 288（2026-11-17，注明以 PRD 为准）。
- **083 新票**：今夜对齐态 chrome 零反馈（`syncMode` 不产出 `.tonight`，derive 分支死代码，
  `SkyObserver.statusText` 零消费）；079-diff A5 已补更正。与 081 同族，079 对照谓词漏检第二例。

## 边界

- 本票不做：ASC 实际建 App/上传/提审（人工）；icon 未确认前不接工程；080 门禁不代判。
- blocked_by 080：截图最终版须用 080 通过后的冻结代码拍摄。