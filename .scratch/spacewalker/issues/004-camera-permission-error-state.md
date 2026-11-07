---
id: 004
title: 权限与错误态
status: ready-for-agent
stage: M0
blocked_by: [001]
---

## 背景

相机权限是 AR 的第一道门。拒绝权限后不能黑屏，也不能反复弹系统框。

## 验收标准

- [ ] 首次进入请求相机权限；允许后直接进入相机画面。
- [ ] 拒绝后显示解释页（为什么需要、能做什么），含"去设置"按钮。
- [ ] 从设置授权后返回应用，可正常进入，不要求重启。
- [ ] 连续拒绝 3 次不崩溃、不重复弹框。
- [ ] 解释页可被 VoiceOver 读出。

## 测试缝

- 权限状态机：输入授权状态与来源 → 输出应展示的页面（纯函数）。

## 备注

- 解释页文案走集中管理，不硬编码在视图里。
- 不请求相册、麦克风等无关权限。

## 实现进展（2026-11-07）

三条可由 agent 取证，两条必须人工。

- 已实现：`CameraPermissionState`（AV 状态映射）、`PermissionGate`（状态 → 页面，纯函数）、`PermissionState`（Redux 切片）、`PermissionView` / `PermissionRequestingView`、`PermissionCopy`（文案集中）。
- 真机证据：已授权进入 AR 画面；拒绝态解释页含「去设置开启相机权限」；受限态解释页无按钮。见 `docs/gates/M0/004-*.jpg` 与 `logs/004-*.log`。
- 单次请求：`requestedThisLaunch` + `PermissionGate.shouldRequestAccess` 保证启动内只请求一次，拒绝后不再弹框；对应单测覆盖。
- 待人工：① 真机设置里关闭相机 → 重进看解释页 → 设置里打开 → 返回应用能否直接进入（代码路径是 `scenePhase == .active` → 重新读权限 → 展示内容页，但未实测返回场景）；② 连续拒绝 3 次不崩；③ VoiceOver 朗读顺序与文案。
- 备注：本机相机权限一直是已授权状态，拒绝/受限两态由 `SPACEWALKER_FORCE_PERMISSION` 注入复现。
