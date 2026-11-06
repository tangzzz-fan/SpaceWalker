# SpaceWalker 术语表

本表是 PRD、ADR、issue 与代码命名的唯一词源。新术语先入表再使用；同一概念不得出现两个中文名。

| 术语 | 英文 / 代码名 | 定义 | 不指什么 |
|---|---|---|---|
| 锚点 | Anchor | 把虚拟内容固定在真实世界坐标系中的参考点或参考面 | 不是 UI 的定位点 |
| 追踪会话 | SpatialTrackingSession | 驱动追踪、场景理解与相机背景的会话对象 | 不是网络会话 |
| 能力探测 | Capability probing | 启动会话后读取 `unavailableCapabilities` 并决定降级 | 不是崩溃后的 try-catch 兜底 |
| 实体 | Entity | RealityKit 场景节点 | 不是 Core Data 实体 |
| 组件 | Component | 挂在实体上的数据与行为单元 | 不是 SwiftUI View |
| 系统 | System | 每帧处理组件的逻辑单元 | 不是操作系统 |
| 命中 | Hit test | 把触摸或视锥映射到具体实体 | 不是网络请求命中 |
| 视锥选中 | Frustum selection | 用设备姿态与相机视锥决定选中目标，不依赖触摸 | 不是眼动追踪 |
| 星海 | Star field | B 阶段的房间级星点场 | 不是天文学意义的星系 |
| 命名星体 | Named star | B 阶段允许被选中的 20 颗星体，其余星点为背景（FR-B-02） | 不是所有可见星点 |
| 天宫一号 | Tiangong-1 | 中国首个目标飞行器/空间实验室（2011–2018），C 阶段任务场景 | **不是**空间站，也不是天宫空间站 |
| 门禁 | Gate | 阶段交付前必须通过的验证关卡（M0–M3） | 不是 CI 流水线 |
| 节点提交 | Commit per node | 每个可验证步骤完成后立即提交 | 不是每个文件一次提交 |
| 基准机型 | Reference device | iPhone 16 / iOS 26.6（无 LiDAR），性能与体验的判定基准 | 不是最低兼容机型 |
| 降级模式 | Degraded mode | 关闭遮挡/物理/网格，仅保留基础放置与触摸交互；旧文档里的"基础模式"已废弃 | 不是错误恢复页 |
