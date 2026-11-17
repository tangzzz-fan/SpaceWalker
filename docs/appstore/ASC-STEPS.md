# ASC 上架最短路径清单（人工网页操作，agent 已备好全部材料）

> 2026-11-17 · 董事长裁决：ASC 走人工网页操作（无 API key）。
> 预计总耗时 20–30 分钟（不含 Apple 构建处理等待 5–15 分钟）。
> 所有字段照抄 `docs/design/APPSTORE.md`；本清单只给顺序与落点。
> 联系邮箱统一：**1139658353@qq.com**（董事长指定）。

## 已就绪材料（agent 完成，直接取用）

| 材料 | 位置 | 状态 |
|---|---|---|
| **IPA（App Store 签名）** | `~/Developments/SpaceWalker-release/星槎-1.0-1.ipa`（8.6MB） | ✅ Distribution 签名、get-task-allow=false、1.0(1)、iPhone-only、icon 1024 无 alpha、出口合规已预答 |
| Bundle ID 注册 | developer.apple.com 已自动注册（Archive 自动签名完成，AppIDName "XC com tango xingcha"） | ✅ 无需手动注册 |
| 隐私政策 URL | **https://tangzzz-fan.github.io/SpaceWalker/** | ✅ 已上线，邮箱已填 |
| 截图 6 张（**1206×2622 必需档**） | `docs/design/appstore-screenshots/01…06*.png` | ✅ 2026-11-17 尺寸修正重采：Dynamic Island medium 档、RGB 无 alpha、9:41 满电状态栏 |
| 截图备用（1320×2868 可选大屏档） | `docs/design/appstore-screenshots-1320/01…06*.png` | ✅ 同一批画面，large 档备用（非必需） |
| App 图标 1024 | `Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | ✅ IPA 已携带，ASC 自动提取（无需单独传） |
| 元数据全文 | `docs/design/APPSTORE.md` §1–§5 | ✅ 逐字段照抄 |

## 步骤（按序）

### ① 建 App（2 分钟）
ASC → 我的 App → ＋ → 新建 App：
- 平台 iOS ｜ 名称 **星槎** ｜ 主要语言 简体中文
- Bundle ID 下拉选 **com.tango.xingcha**（已注册，直接能选到）
- SKU `xingcha-ios-1` ｜ 用户访问权限 完全访问

### ② 上传构建（3 分钟操作 + 5–15 分钟 Apple 处理）
**推荐 Transporter**（Mac App Store 免费装，Apple ID 登录即可，无需 API key）：
打开 Transporter → 拖入 `星槎-1.0-1.ipa` → 交付。
（备选：Xcode → Window → Organizer → Archives → Distribute App → App Store Connect → Upload，需重新 Archive 一次，慢。）
上传后 ASC「TestFlight/构建版本」页等处理完成（会收到邮件）。**处理期间可先做 ③④⑤。**

### ③ App 信息 + 版本元数据（8 分钟，照抄 APPSTORE.md）
- 副标题：`举机观星 · 太阳系 · 天宫一号`
- 类别：主 **教育** / 次 **参考**
- 内容版权：含第三方内容（CC BY-SA 数据 + NASA 公共域，应用内已署名）
- 价格：**免费**（无内购无广告）
- 版本 1.0 页：宣传文本 / 描述 / 关键词 / 新功能「首次发布。」/ 版权 `2026 Tang`（§3 全文照抄）
- 截图：6 张按文件名顺序上传到 **iPhone with Dynamic Island (medium)** 必需档槽位（1206×2622，即 6.3" Pro 档；iPhone-only，无需 iPad）。1320×2868 属 large 可选档，不必传；若页面仍显示旧 6.9" 槽位，传 `appstore-screenshots-1320/` 那套
- 支持 URL / 营销 URL：留空

### ④ App 隐私（3 分钟）
- 隐私政策 URL：`https://tangzzz-fan.github.io/SpaceWalker/`
- 数据收集问卷：**不收集任何数据**（Data Not Collected）→ 无需勾选任何数据类型
- 跟踪：不跟踪（无 ATT）

### ⑤ 审核信息（2 分钟）
- 登录：不需要
- 联系人：姓名 Tang ｜ 邮箱 **1139658353@qq.com** ｜ 电话（人工填）
- 备注：照抄 APPSTORE.md §5 模板（含「天宫一号为目标飞行器非空间站」与演示路径）
- 出口合规：构建已带 `ITSAppUsesNonExemptEncryption=false`，**不会弹问卷**

### ⑥ 年龄分级问卷（2 分钟）
全答「无/否」→ 预计 **4+**。

### ⑦ 提交审核（1 分钟）
版本页选构建 **1.0 (1)** → 右上「添加至审核」→「提交至 App 审核」。
提交后状态变「等待审核」。被拒按意见回票（agent 待命修复）。

## 红线自查（提交前最后一眼）

- [ ] 不得称天宫一号为「空间站」（审核备注中「非空间站」澄清句除外，天宫一号 = 目标飞行器）
- [ ] 无 NASA 标识/「官方」「合作」暗示
- [ ] 描述数字与源码一致：2996 星 / 288 亮星 / 301 星官 / 88 星座
- [ ] 截图第 3 张为今夜对齐态（金色选中）、第 6 张剖面含三标注
- [ ] 隐私政策 URL 可打开且邮箱为 1139658353@qq.com

## 已知边界（不阻塞提审）

- 080 人工门禁（盲测/签字）按 A8 裁决不阻塞实施与上架准备；体验类签字可提审后补。
- 084 真机全链取证：设备掉线待恢复，链路逻辑已 412 项单测全覆盖；不阻塞提审。
- MinimumOSVersion 26.0：仅 iOS 26+ 设备可装（产品既定边界）。