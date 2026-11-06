# Issue tracker

本项目使用 **本地 Markdown issue tracker**：一个 feature 一个目录，一个 issue 一个文件，不依赖远端仓库。

## 位置与命名

```
.scratch/<feature>/issues/NNN-<slug>.md
```

- `NNN` 三位递增编号，不复用、不跳号。
- `slug` 用英文小写连字符，例如 `003-plane-anchoring.md`。
- 当前 feature：`spacewalker`。

## 文件格式

```markdown
---
id: 003
title: 平面锚定与放置
status: ready-for-agent
stage: A
blocked_by: [002]
---

## 背景

## 验收标准

## 测试缝

## 备注
```

## 状态词汇

见 `triage-labels.md`。状态只由人确认流转，agent 不自行标记 `wontfix`。

## 工作方式

1. 只领取 `blocked_by` 全部完成的 issue（blockers-first）。
2. 每个 issue 独立完成、独立验证、独立提交；commit message 引用 issue 编号。
3. 实现前先补测试缝；实现后必须附实测证据（构建输出、测试结果、真机截图或 runtime log）。
4. issue 与 PRD 条款冲突时，以 PRD 为准并回写 issue；PRD 需要变更时先改 PRD 再改 issue。
