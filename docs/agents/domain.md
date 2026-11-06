# Domain docs

**布局：单上下文（single-context）。**

- 术语表：仓库根目录 `GLOSSARY.md`
- 架构决策记录：`docs/adr/ADR-NNNN-<slug>.md`
- 产品需求：`docs/PRD.md`
- 评审记录：`docs/reviews/`
- 一手资料：`docs/research/`

## 读取规则

1. 写 PRD、ADR、issue 或代码命名前，先读 `GLOSSARY.md`；同一概念必须使用表中词条。
2. 触及已被 ADR 决定的事项，先读对应 ADR；要推翻时新写一条 ADR 并在旧 ADR 标注 `Superseded by ADR-NNNN`，不得直接改写结论。
3. 新术语先入 `GLOSSARY.md` 再使用；发现两个词指同一概念，立即合并并保留一个别名指向。
4. PRD 与 ADR 冲突时，ADR 管"为什么这样选"，PRD 管"做什么、做到什么程度"；实现冲突以 PRD 为准，选型冲突以 ADR 为准。
