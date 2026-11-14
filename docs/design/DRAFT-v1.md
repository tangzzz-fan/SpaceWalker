# 星槎 · UI 设计稿 v1（open-design 产出）

> 生成时间：2026-11-14 22:38
> 工具：OpenDesign 本地项目 `xingcha-ui-v1`，agent = Claude Code（DeepSeek-V4.1-Flash）
> 状态：**待评审**，未进入实现

## 打开方式

- 本地文件：`/Users/tango/Developments/Open-Design-Projects/.od/projects/xingcha-ui-v1/index.html`
- 预览地址（仅本机、daemon 会话内有效）：`http://127.0.0.1:7457/api/projects/xingcha-ui-v1/raw/index.html`
- OpenDesign Studio：`http://127.0.0.1:7456/projects/xingcha-ui-v1`

参考图：`docs/design/draft/cover.png`、`screen-a5-tonight.png`、`screen-c6-drawing.png`

## 交付内容（已核对）

| 项 | 结果 |
|---|---|
| 单文件 | `index.html` 1.1 MB，CSS 内联 + 引用 `assets/doc.css`、`assets/screens.css`；无 JS、无外链；3 张现状截图以 data URI 内嵌 |
| 14 屏 | A1–A5、B1–B2、C1/C2/C4–C8，均按 402×874 单列排布，每屏下方 12pt 屏注 |
| token 表 | 颜色 / 形状 / 布局 / 字体 / 间距 / 动效 / 文案规则，七张表 |
| 组件 | 8 个：状态条、信息卡、任务条、读数块、标签、底部 tab、菜单、toast |
| 图标 | 38 个，SF Symbols 映射 + 需要自绘的标注 |
| 动效 | 6 条，归到相机 450ms / 面板 280ms / 状态 150ms 三类原语 |
| 分镜 | 首进入 30 秒，4 格 |
| 对照 | 三组现状截图，逐条标注删了什么、为什么 |
| 自查 | 14 项验收清单 |

**硬约束核对**：全稿「空间站」出现 0 次；史实日期只用 2011-09-29 / 2016-03-16 / 2018-04-02；主界面无 fps/pick 等调试串（仅第 08 节对照区引用旧版字符串作反例）；C1 默认态零浮标。

## 评审时重点看三处

1. **C1 天宫默认态**：是否真的没有浮标压模型，选中态是否只出一个标签。
2. **C4 对接 HUD**：距离读数、姿态偏差、容差环、粗调/精调、四类失败原因是否都在一屏内可读。
3. **底部导航的辨识度**：三个模块是否不看标题也能分清。

## 与任务书的两处偏差（设计方已声明）

- 主操作放顶栏 44pt 状态条（任务书 §9 曾要求「主操作在屏幕下 40%」）。最新简报优先，底部保留高频单手控件；这是取舍，需要在实现前定。
- 工程图的「翼展」「转移通道」写成「由模型计算」，不编造数值——符合「标注与常量同源」的要求。

## 下一步

评审通过后按 `docs/design/PRD-UI-v1.md` 的信息架构落实现；token 落地时以本稿第 02 节表格为准，代码里不写裸值。
