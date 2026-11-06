# Triage labels

五个角色，标签字符串与角色名一致，不另造同义词。

| 标签 | 含义 | 谁来决定 |
|---|---|---|
| `needs-triage` | 新进来、尚未判断 | 人 |
| `needs-info` | 信息不足，等待补充 | 人 |
| `ready-for-agent` | 验收标准与测试缝齐备，可交给 agent 实现 | 人 |
| `ready-for-human` | 需要人操作（真机、账号、设计裁决） | 人 |
| `wontfix` | 明确不做 | 人 |

规则：

- 一个 issue 同时只有一个状态标签。
- 从 `needs-triage` 进入 `ready-for-agent` 的前提是：验收标准可测、依赖已清、涉及的真机能力已确认可用。
- 真机专属验证（AR 追踪、遮挡、性能）不得由 agent 自行判定通过。
- 含真机验收的实现 ticket 标 `ready-for-agent`，真机验收统一由对应门禁 ticket 承接（M0→006，M1→011）；纯真机项（门禁、验收清单）标 `ready-for-human`。
