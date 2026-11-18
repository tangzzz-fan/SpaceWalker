# 星槎 1.0 · App Review「补充信息」应答包

> 日期：2026-11-18 ｜ 触发：Apple 2.1 Additional Information（模板化，要求 6 项）
> 产出：① 可直接粘贴的英文 Notes（§2，≤4000 字节已核）② 真机录屏分镜（§3）③ 六项对照（§4）④ 提交核对（§5）
> 事实来源：`APPSTORE.md` §2–§5、`project.yml`、源码核查（无 `URLSession`/`WKWebView`/第三方 SDK）、`devicectl` 实测设备
> 唯一硬缺口：**真机录屏**（Apple 第 1 项）。其余 5 项都是文字，本文件已写完。

---

## 1. Apple 要什么 / 我们有什么

| # | Apple 要求 | 现状 | 本次动作 |
|---|---|---|---|
| 1 | 真机 + 最新系统录屏，从启动开始，含账号/UGC/付费流程 | **缺**；且本 App 三类都不存在（无账号、无 UGC、无内购） | §3 分镜，人工录一次 |
| 2 | 用途、目标用户、解决的问题、价值 | 现有备注只有 4 行，未写受众与价值 | §2 第 1 段 |
| 3 | 设置与访问主功能的说明（含账号/样例文件） | 无登录，但路径从未成文；UI 全中文，评审易迷路 | §2 第 2、8 段（含中英标签对照） |
| 4 | 外部服务/工具/平台清单 | 运行时无任何外部服务；素材有 CC 许可 | §2 第 4 段 |
| 5 | 区域差异说明或「全球一致」确认 | 全球一致，但 UI 仅简体中文（易被当成区域限制） | §2 第 5 段 |
| 6 | 受监管行业 / 受保护第三方素材的授权材料 | 非受监管；素材 CC BY-SA + 公共域，应用内已署名 | §2 第 6 段 |

**省字节的写法**：第 1 项里「账号 / UGC / 付费」三类一次讲清不适用（§2 第 7 段），避免评审二次追问。

---

## 2. 粘贴进 Notes 的正文（英文，可直接复制）

> 落点：ASC → 版本页 → App Review Information → Notes。
> 仅替换 `<RECORDING-URL>` 一处；`Sign-in required` 不勾；联系人邮箱 `1139658353@qq.com`。
> 字节数见本节末尾；英文按 1 字节/字符，中文标签按 3 字节/字，改动中文标签时要重算。

```text
星槎 (Xingcha) 1.0 (build 1), iPhone, iOS 26.0+

1. PURPOSE AND AUDIENCE
星槎 is an offline astronomy education app with three tabs: a sky map that follows the device's motion (2,996 Hipparcos-based stars, 88 Western constellations, 301 traditional Chinese asterisms); the solar system with the eight planets orbiting at their real relative periods; and a 1:20 interactive model of Tiangong-1, China's first space laboratory (2011-2018) - disassemble it, reassemble it, dock Shenzhou, cut it away, and deorbit it.
Audience: students and general readers curious about the night sky and Chinese space history.
Value: sky apps are passive maps and 3D models are not interactive; here the user holds the sky in their hand and takes a real spacecraft apart, offline.

2. SETUP AND ACCESS
No login, demo account or sample files. Install and open; content is on screen at launch.
iPhone only; requires iOS 26.0 or later.
Location is optional: only "Tonight" asks for it, and declining keeps the rest working in equatorial coordinates (status reads 定位被拒绝 · 仍显示赤道坐标).

3. SCREEN RECORDING
<RECORDING-URL>
Physical iPhone 16 Pro, iOS 27.0 (current public release). Starts on the Home Screen and launches the app cold; shows the device-motion sky map, star selection, the asterism layer, Tonight alignment with the location prompt, the solar system, and the Tiangong-1 flow (disassembly, reassembly, docking, cutaway, drawing, history, reentry).

4. EXTERNAL SERVICES AND PLATFORMS
None at runtime: no network requests, no third-party SDK (no analytics, ads, authentication, payment or AI). All content ships in the app.
Third-party material, credited in-app ("..." menu > 素材来源 / Credits):
- HYG Database v4.1, CC BY-SA 4.0 (star catalogue)
- Stellarium Chinese Sky Culture, CC BY-SA (301 asterisms)
- NASA/Goddard SVS Deep Star Maps 2020, public domain (background)
No NASA logo or insignia is used; no affiliation with any space agency is claimed.

5. REGIONAL DIFFERENCES
None; every feature is identical in all regions and works offline. The interface is Simplified Chinese only (the app's primary language). No content is geo-restricted. Coordinates are computed on device from an optional coarse location (~3 km) and never transmitted.

6. REGULATED INDUSTRY / PROTECTED MATERIAL
Not a regulated service. Tiangong-1 dimensions and dates come from published sources; the model is a 1:20 schematic, not engineering data. Third-party material is licensed as in 4, with in-app attribution. Tiangong-1 is a target spacecraft and space laboratory, not a space station.

7. NO ACCOUNT, UGC OR PAID CONTENT
No login, so no account deletion flow. No user-generated content, so no reporting or blocking is needed. Free, with no in-app purchase, subscription or paid content.

8. WALKTHROUGH (on-screen labels are Chinese; English in brackets)
Bottom tabs: 星图 [Sky] · 太阳系 [Solar System] · 天宫一号 [Tiangong-1].
星图: turn the phone to look around; tap a star or constellation for its card. 图层 [Layers] toggles constellation and asterism layers. 今夜 [Tonight] asks for location and aligns the map to the real sky. 找星 [Find] searches stars by name.
太阳系: 暂停 [Pause], 流速 [Rate], 轨道 [Orbits]; tap a planet, then 聚焦 [Focus].
天宫一号: 开始拆解 [Start disassembly]; tap a module, then 分离 [Separate]; drag each module back onto its port to snap it on. After the fourth, docking starts automatically: 推进 [Approach], 粗调/精调 [coarse/fine], hold inside tolerance for 1 s. Then 剖面 [Cutaway], 工程图 [Drawing], 史实 [History], 再入 [Reentry]; 再入 unlocks after the three-step mission and one visit to 史实.
```

**字节数：3704 / 4000（占位符 `<RECORDING-URL>` 按 15 字节计）**，真实链接替换后约 3715–3765，仍在 Apple 的 4000 字节上限内（英文 1 字节/字符，中文标签 3 字节/字；改中文标签后须重算）。

> 上限是**字节**不是字符：粘贴框里再补中文，很快会顶满。

---

## 3. 录屏 runbook（人工执行，约 40 分钟）

### 3.1 设备与系统（已实测，勿换机）

| 项 | 值 |
|---|---|
| 设备 | Tango · iPhone 16 Pro（iPhone17,1）· UDID `00008140-000A288836FB001C` |
| 系统 | **iOS 27.0（24A437）** ｜ `devicectl` 实测 2026-11-18 |
| App | `com.tango.xingcha` 1.0 (1)，即上架同源包 |
| 方向 | 全程竖屏（App 支持横屏，但分镜不做） |
| 外观 | 保持 App 默认深色，录制中不要切主题 |

> 录前先看「设置 → 通用 → 软件更新」：若已有 27.x 更新，先升级再录，并同步改 §2 第 3 段的版本号。Apple 要看的是「最新系统」。

### 3.2 录前准备（8 项，缺一项就废片）

1. **冷启动**：先从多任务里把星槎划掉，确保首次画面是「桌面 → 点图标 → 启动」。
2. **重置定位授权**：设置 → 隐私与安全性 → 定位服务 → 星槎 → 选「下次询问」。（重装也会重置；不重置则录不到权限弹窗，第 1 项要求就少一块。）
3. **勿扰**：开「专注 · 勿扰」，避免通知横幅入镜。
4. **电量与存储**：≥50% 或插电；剩余空间 ≥8GB（4K 录屏很吃空间）。
5. **亮度与自动锁定**：亮度约 70%；设置 → 显示与亮度 → 自动锁定 → 「永不」，防止中途息屏。
6. **关掉诊断入口暴露**：录制中**不要**长按顶部标题 3 秒（会开诊断面板，看起来像测试包），也不要点 `…` 里的「切换亮色」。
7. **清桌面**：把星槎图标放在首屏可见位置；桌面不要出现带内部信息的文件夹名。
8. **彩排一次不录**：确认 4 段分离 + 4 段装回都能吸附成功、对接 1 秒容差能稳住。对接超时 90 秒、容差角度 5°、横向偏差 2cm、需保持 1s（源码常量），失败会显示具体原因，允许点「重试」。

### 3.3 分镜表（目标 5 分 30 秒以内，一镜到底）

| 时间 | 操作 | 画面必须交代的要点 |
|---|---|---|
| 0:00–0:06 | 桌面起录 → 点「星槎」图标 | **首帧必须是桌面**；冷启动，无闪屏停留 |
| 0:06–0:30 | 星图默认页 → 举机左右缓转 + 上下俯仰 | 星空随手腕转动（姿态跟随）；顶部状态条「姿态跟随 · 转动手机环顾」 |
| 0:30–0:50 | 点一颗亮星（织女/天狼均可）→ 弹出信息卡 → 下滑关闭 | 卡片含名称、星等、方位高度（证明不是贴图） |
| 0:50–1:10 | 底部「图层」→ 开「星官」→ 关闭面板 | 301 星官层（差异化卖点，与西方星座同屏） |
| 1:10–1:40 | 点「今夜」→ iOS 定位弹窗 → 允许 → 星图对齐真实天空 | **权限文案要入镜**；对齐后状态条变「今夜此刻 · 时间与方位已对齐」 |
| 1:40–1:55 | 点「找星」→ 输入「天狼」→ 点结果 → 指路箭头 | 搜索 + 指路（可选，时间紧可删） |
| 1:55–2:20 | 切「太阳系」→ 暂停/流速/轨道 → 点行星 → 聚焦 | 行星沿轨道运行、时间流速变化 |
| 2:20–2:55 | 切「天宫一号」→ 点「开始拆解」→ 逐段「分离」（4 段） | 分离动画 + 任务进度「拆解 n/4」 |
| 2:55–3:40 | 逐段拖回接口 → 松手吸附（4 段） | 吸附高亮与回弹；第 4 段装回后**自动进入对接** |
| 3:40–4:20 | 「推进」接近 → 「粗调/精调」修正 → 容差内保持 1 秒 → 对接成功 | 容差读数（角度/横向）、成功提示；失败则点「重试」继续，不要剪断 |
| 4:20–4:55 | 「剖面」→ 退出 → 「工程图」→ 正/侧/俯视图 → 退出 → 右上「…」→「史实与里程碑」→ 完成 | 舱内三标注（睡眠区/健身区/设备机柜）、三视图、史实卡 |
| 4:55–5:20 | 「再入」→ 三幕动画 → 关闭 | 再入按钮解锁前置：三步任务完成 + 看过史实（这一步必须在同一次会话内完成） |
| 5:20–5:30 | 右上「…」→「素材来源」 | 许可证署名（对应第 6 项，10 秒即可） |
| 5:30 | 停止录制 | — |

> 若某段操作明显拖沓（装配反复吸不上），**不要重录整条**：保留失败反馈也是真实行为，只要后续完成即可；只有在出现通知横幅、诊断面板、横屏时才整条重录。

### 3.4 录制与导出

- 控制中心 → 屏幕录制（长按可开关麦克风）。**建议关麦克风**：无旁白不会扣分，备注已给逐步说明；若要旁白，用英文短句，别即兴发挥。
- 结束后：相册 → 检查时长、首帧、有无横幅 → AirDrop 到 Mac → 命名 `xingcha-1.0-review-demo-2026-11-18.mp4`。
- 体积过大时用 QuickTime 导出 1080p（H.264），保证文字清晰、不要压到糊。

### 3.5 上传与链接

| 方式 | 做法 | 注意 |
|---|---|---|
| **首选：ASC 附件** | App Review Information → Attachment 上传 mp4 | Apple 未公布大小/格式上限；超大文件先压 1080p |
| 备选：未列出链接 | YouTube（Unlisted）/ Vimeo / iCloud 云盘共享 / Dropbox | **不得要求登录、不得设有效期**；链接填到 §2 第 3 段 |
| 自测 | 无痕窗口 + 手机蜂窝网络各开一次 | 能直接播放、无权限申请，才算过 |

> 两种一起做最稳：附件传文件，Notes 里同时放链接——附件失败时评审还能看链接。

---

## 4. 六项对照与红线

| Apple 项 | 落点 | 验收方式 |
|---|---|---|
| 1 录屏 | §3 分镜 + §2 第 3 段链接 | 首帧桌面、含权限弹窗、含对接与再入、真机 27.0 |
| 2 用途/受众 | §2 第 1 段 | 一段说清「是什么 / 给谁 / 解决什么」 |
| 3 设置与访问 | §2 第 2、8 段 | 明确「无登录」，给出中英标签路径 |
| 4 外部服务 | §2 第 4 段 | 明确「无」+ 三项素材许可 |
| 5 区域差异 | §2 第 5 段 | 「全球一致」+ 说明 UI 仅简体中文、定位不出设备 |
| 6 受监管/第三方 | §2 第 6 段 | 非受监管 + 许可清单 + 「非空间站」澄清 |

**红线**（沿用 `ASC-STEPS.md`）：不得称天宫一号为空间站（澄清句除外）；不出现 NASA 标识或「官方/合作」暗示；数字与源码一致（2996 / 288 / 301 / 88）。

---

## 5. 提交前核对表

- [ ] `…` 菜单能打开「素材来源」，署名三项齐全
- [ ] 定位授权已重置为「下次询问」，录屏中确实出现弹窗
- [ ] 录屏首帧是桌面，且是冷启动
- [ ] 录屏无通知横幅、无诊断面板、全程竖屏
- [ ] 视频链接无痕窗口可播、无需登录、无有效期
- [ ] Notes 粘贴后字节数 ≤4000（粘贴框粘贴完直接看剩余量；改动中文标签必须重算）
- [ ] Notes 里 `<RECORDING-URL>` 已替换，无残留尖括号
- [ ] 版本页选中的构建仍是 1.0 (1)，与录屏同源
- [ ] 提交后在 Resolution Center 回一句「materials added」，便于对上话

---

## 6. 为什么会走到这一步（判断，不是事实）

三条最可能的触发，按概率排：

1. **评审在中文 UI 里找不到主线**。3 个页签全是中文，`再入` 还是灰的（需完成任务+看史实），没有英文对照时 5 分钟内很难判断「这个 App 到底能干什么」。→ 第 8 段标签对照 + 录屏是正解。
2. **被当成技术演示**（2.2 最低功能）。三页纯 3D、无账号无网络，首屏信息密度低。→ 第 1 段明确内容量与交互深度，录屏给出完整任务链。
3. **权限用途没说清**。定位只在「今夜」触发，评审若拒授权，看到的是赤道坐标模式，容易误判为「功能不完整」。→ 第 2 段与录屏里都交代了拒绝后的降级行为。

> 建议顺手翻一下 Resolution Center 该条消息的**上半部分**：模板正文之前通常有一句评审自己写的话（例如「we could not locate the main features」）。有的话把原句贴给我，可按那句话再收紧措辞；没有也不影响本次提交。

---

## 7. 我们改了什么（本轮）

- 新增本文件（Notes 正文 + 录屏分镜 + 对照表）
- `ASC-STEPS.md` §⑤ 指向本文件，避免两处备注模板分叉
- `HUMAN-TASKS.md` 增 C7：录屏 + 补充材料回填
- 未改任何代码、未动构建与签名
