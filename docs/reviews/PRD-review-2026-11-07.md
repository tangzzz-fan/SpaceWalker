# PRD 评审报告（2026-11-07）

## 评审设置

| 项 | 内容 |
|---|---|
| 评审对象 | `docs/PRD.md` v0.1 |
| 评审方式 | 两轴独立评审：产品轴、技术轴各自独立上下文，互不可见 |
| 评审人 | 产品负责人（独立）、iOS 技术负责人（独立） |
| 汇总与裁决 | 项目总监 |
| 结论 | **需修订后通过**。产品轴 4 项 Blocking、技术轴 4 项 Blocking（含 3 处平台事实错误），全部关闭后升级为 v0.2 |

## 一、产品轴

### Blocking（全部采纳，已修）

| # | 问题 | 处理 |
|---|---|---|
| P-B1 | §11.3 的 DoD 以 P0/P1 为前提，但 §7/§9 所有 FR/NFR 均未标优先级，DoD 无法执行 | 全部 FR/NFR 补 `[P0]`/`[P1]`；NFR 表增加"适用阶段"列 |
| P-B2 | 帧率口径四处互斥：G5、NFR-01、FR-B-06、M2 对 A/B/C 的目标与底线不一致 | 统一为：A/B 平均 ≥ 55fps、下限 30fps；C 平均 ≥ 25fps、下限 20fps；四处同步 |
| P-B3 | FR-X-03 引用"偏差见 NFR"，但 NFR 中没有漂移阈值，属悬空引用 | 新增 NFR-10（绕桌一周偏移 ≤ 20cm），FR-X-03 与 FR-B-04 共用 |
| P-B4 | 术语与角色冲突："基础模式"与术语表"降级模式"是同一概念两个名字；"首次使用者"未在角色表定义；FR-X-02 的"阴影"与术语表不一致 | 全文统一"降级模式"；§4.1 增加"首次使用者"；术语表补注废弃别名；"阴影"属场景理解能力，不与术语表冲突 |

### Major

| # | 问题 | 处理 |
|---|---|---|
| P-M1 | §5 退出条件写"M1/M2/M3 门禁全过"，属循环定义；ADR-0002 允许 A 后推翻 B，PRD 未承接 | 保留门禁表述（门禁定义在 §11.2，非循环），§5 新增"失败止损"列 |
| P-M2 | 尺度冲突：§4.2 的 2m×2m 与 B 的 5m 活动半径、A 的 0.6–1.2m 与 1m×1m 桌面 | 统一：A 0.6–1.2m；B 生成半径 3m、活动半径 4m（约 4m×4m）；C 1:20、主体 0.52m |
| P-M3 | 主观验收无阈值：FR-A-04"不抖动"、FR-B-01"明显重复"、FR-B-05"可见跳变"、G2"肉眼可辨" | 补量化：单帧回退 < 2mm、同屏重复率 < 5%、LOD 尺寸差 < 10%、漂移 ≤ 20cm |
| P-M4 | NFR-02/03/04/09 未挂到任何里程碑或 DoD | NFR 表增加"适用阶段"，§11.2 与 §11.3 引用 |
| P-M5 | §8.1 长按映射了 B"星体详情"、C"模块菜单"，但 §7 无对应 FR | B 阶段长按删除；A 长按对应 FR-A-05；C 长按对应 FR-C-04 粗调/精调 |
| P-M6 | Q1/Q2 是伪开放问题：Q1 已由术语表与 FR-C-01 定案，Q2 已由 FR-A-02 与附录 A 定案 | 删除旧 Q1/Q2；新增 5 个真问题（B 可选中星体数量、C 纹理资产、iPad、音频素材、密度上限） |

### Minor

| # | 问题 | 处理 |
|---|---|---|
| P-m1 | NFR-02 名为"首帧"，实际测"可交互时间" | 改为"冷启动到出现落点准星 < 1.5s（不含锚定完成）" |
| P-m2 | NFR-06"不录制"与门禁录屏证据冲突 | 注明录屏由人工在应用外完成，不属于应用行为 |
| P-m3 | "评审者"角色无用户故事 | 保留角色，标注"不产生用户故事" |
| P-m4 | Q5 默认假设直接决定 FR-B-03 验收 | 转为技术负责人决策项（默认合成音），不再作为开放问题阻塞 |

## 二、技术轴

### Blocking（全部采纳，已修）

| # | 问题 | 核实结果 | 处理 |
|---|---|---|---|
| T-B1 | `ManipulationComponent` 是 visionOS-only，iOS 不可用 | Apple 文档：**visionOS 26.0+** | 从 §10 删除；FR-A-04 改为 SwiftUI 手势 + 命中组件 + 自行解算；ADR-0001 修订 |
| T-B2 | `EnvironmentBlendingComponent` 是 visionOS-only，且仅沉浸空间生效 | Apple 文档：**visionOS 26.0+**，仅混合/渐进沉浸空间 | 从 §10 删除；遮挡改为 `sceneUnderstanding: [.occlusion]`；ADR-0001 修订 |
| T-B3 | 基准机型 iPhone 16 无 LiDAR，遮挡与网格重建不可达 | Apple 中国官网对比页：iPhone 16 激光雷达"不适用"，16 Pro 才有 | G2 下调为"锚定稳定 + 接触阴影，遮挡尽力而为"；FR-A-03 遮挡降为 P1；风险表新增该风险 |
| T-B4 | `MeshInstancesComponent` 实例不是 Entity，无法挂命中组件 | Apple 文档：实例是 `LowLevelInstanceData`，无独立 Entity 身份 | FR-B-02 与 §8.2 改为屏幕投影 + 射线-球解析判定；选中反馈由独立实体承载 |

### Major

| # | 问题 | 处理 |
|---|---|---|
| T-M1 | 帧率缺度量条件（分辨率、实例面数、透明过绘制、后处理） | FR-B-06 补"2000 实例、1080p、无后处理"；M2 同步 |
| T-M2 | NFR-02"可交互"未定义，会话启动 + 首锚点通常已超 1.5s | 改为"出准星 < 1.5s，锚定另计" |
| T-M3 | NFR-04"不过热"不可证 | 改为"第 10 分钟平均 ≥ 52fps、thermalState ≤ .fair、环境 25℃" |
| T-M4 | FR-X-03 假设会话可暂停，实际只有 run/stop | 改为"停止会话，回前台重新 run；不承诺 ARWorldMap 级重定位" |
| T-M5 | FR-C-04 无六自由度输入映射；0.1m/s 未按 1:20 尺度换算，等于真实 2m/s | 补输入映射；容差改为展示尺度 0.02m/s、轴向 ≤ 2cm、姿态 ≤ 5°、角速度 ≤ 5°/s、保持 1s |
| T-M6 | FR-C-03"物理吸附 + 100% 拒绝"与物理非确定性冲突 | 改为"规则判定（距离 + 轴夹角 + 接口 ID）+ 动画吸附" |

### Minor

| # | 问题 | 处理 |
|---|---|---|
| T-m1 | ADR-0001 称"iOS 26 起有 SpatialTrackingSession"，实际 iOS 18+ | ADR 已修订：iOS 18+；部署目标取 26 的实际原因是 `MeshInstancesComponent` |
| T-m2 | 44pt 命中不必用透明包围盒 | 改为按相机距离逐帧换算世界尺寸，使用碰撞形状 |
| T-m3 | "<50ms 跟手"未定义测点 | 明确为"触摸事件到 transform 更新"，不含显示链路 |
| T-m4 | FR-B-03"左右可辨"在内置扬声器上不成立 | 改为"戴耳机时左右可辨" |
| T-m5 | FR-B-01 半径 3m 与 FR-B-04 活动 5m 冲突 | 统一为生成 3m、活动 4m |

### 不采纳

| # | 建议 | 理由 |
|---|---|---|
| T-N1 | 将"ManipulationComponent 是否真在 iOS 26 缺失"列为待真机验证 | 文档 availability 已明确为 visionOS 26.0+，事实已闭合；M0 仍会用 SDK 头文件复核，但不再作为"未证实"事项 |

## 三、事实核查记录

| 结论 | 一手来源 | 结果 |
|---|---|---|
| `ManipulationComponent` 为 visionOS 26.0+ | developer.apple.com/documentation/realitykit/manipulationcomponent | 证实 |
| `EnvironmentBlendingComponent` 为 visionOS 26.0+，仅混合/渐进沉浸空间 | developer.apple.com/documentation/realitykit/environmentblendingcomponent | 证实 |
| `MeshInstancesComponent` 为 iOS 26.0+，实例是 `LowLevelInstanceData` | developer.apple.com/documentation/realitykit/meshinstancescomponent | 证实 |
| `SpatialTrackingSession` 为 iOS 18.0+，`run(_:)` 返回 `UnavailableCapabilities?` | developer.apple.com/documentation/realitykit/spatialtrackingsession | 证实 |
| iPhone 16 无 LiDAR，iPhone 16 Pro 有 | apple.com.cn/iphone/compare | 证实 |
| 天宫一号 2011-09-29 发射、6 次对接、2018-04-02 再入 | cmse.gov.cn 官方任务大事记 | 证实 |

## 四、裁决与遗留

- **通过条件**：4 + 4 项 Blocking 全部关闭。已全部关闭，PRD 升级为 v0.2。
- **遗留 Major**：无。
- **遗留 Minor**：3 条（录屏例外说明、评审者角色、音频素材决策），已记录，不阻塞 M0。
- **需要 Tang 拍板**：Q1（可选中星体数量）、Q2（C 阶段是否引入纹理资产）、Q3（是否适配 iPad）。
- **下一步**：M0 可行性门禁。先用最小验证样例在 iPhone 16 上确认：会话启动、平面锚定、能力清单、`.occlusion` 实效、2000 实例帧时间。

## 五、评审方法

- 两轴独立、互不可见，避免一方结论掩盖另一方。
- 每条 finding 必须引用 PRD 条款编号；事实类 finding 必须附一手来源。
- 项目总监对采纳与否负责；不采纳必须给理由（见"不采纳"表）。
- 评审不是一次性仪式：M0 真机数据回来后，需对本报告的技术假设做一次复核。
