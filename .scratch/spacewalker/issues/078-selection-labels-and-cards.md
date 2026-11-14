---
id: 078
title: 选中进 Store、标签与信息卡
status: ready-for-agent
stage: M3
blocked_by: [077]
---

## 背景

让「选中」只有一条路径：三个模块的选中都通过 Store action 通知，标签与信息卡由 `ChromeState` 派生。天宫默认一个浮标都没有，点中实验舱才出那一个标签；信息卡从底部升起、可下滑关闭、不遮挡主操作。

父 spec：074。

## 验收标准

- [ ] 星图 / 太阳系 / 天宫选中统一 dispatch 进 Store；View 不再各自用 `@State` + `if` 决定标签与卡片
- [ ] `selected == nil` → `visibleLabels` 空且 `infoCard == nil`；选中实验舱 → `visibleLabels == [.lab]` 且 `infoCard != nil`
- [ ] 天宫默认态零浮标；选中只出该模块一个标签 + 一条引线
- [ ] 信息卡高度 ≤32% 屏高、下滑可关、停在主操作上方
- [ ] 既有对接 / 剖面 / 工程图 / 再入 / 轨道时钟行为零回归，相关测试全绿
- [ ] 358 项既有测试全绿 + 新增 `ChromeState` 选中派生断言

## 测试缝

`ChromeState` 选中派生 + `TestStore`；session 行为沿用既有单测，不新开缝。

## 备注

- 父票 077。这是本次唯一跨 session / scene 边界的改动，动手前先确认既有 session 接口未被破坏。
- 标签降级（常驻 → 选中才显示）的最终结论由人工门禁 080 的盲测承接，本票不自行宣告体验达标。
- 每步完成后提交，commit message 引用 078。
