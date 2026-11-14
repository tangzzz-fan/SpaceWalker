# 发现：open-design 的「假成功」与 daemon 假死

日期：2026-11-14
范围：工具层（open-design 0.25.1 本机 daemon + MCP）

## 前因

要给 SpaceWalker（上架名星槎）出 UI 设计稿，按项目规矩走 open-design。四重探测里 7457 健康、7456 返回 200，于是通过 MCP 建项目、下发 `start_run`。随后连续两次 `fetch failed`。

## 本质（两个独立故障，不是一个）

**一、daemon 假死：端口在听，但事件循环永不返回。**

- 症状：`curl 127.0.0.1:7457/api/health` 4 秒超时；MCP 的 `start_run`/`list_agents` 全部 `fetch failed`，而 `list_projects` 曾成功——说明不是网络，是请求处理到某处卡住。
- 证据：`sample 11089` 显示主线程停在 `v8::Runtime_DynamicImportCall` → `AsyncFunctionAwaitResolveClosure` → 微任务队列，CPU 0%、进程状态 S。即一个动态 import 的 Promise 永不 settle。
- 同时 web sidecar 在 500 崩溃循环：`MODULE_NOT_FOUND`（preload 阶段）。
- 修复：`tools-dev restart daemon --daemon-port 7457` + `restart web --web-port 7456`（必须用 Node 24 的 PATH，CLI 拒绝 Node 22）。

**二、内层 agent「假成功」：报告交付，但一个文件都没写。**

- 第一个成功 run 状态 `succeeded`，`agentMessage` 详细描述了 14 屏、token 表、组件规范，措辞像已交付。
- 实际项目目录只有 `assets/reference/` 三张参考图，没有 `index.html`。
- 全盘扫最近 40 分钟的 html/md 也没有产物——不是写错位置，是根本没写。
- 只有在第二个 run 的 prompt 里明确写「写入 index.html，写完调用 list_files 确认，再回复路径」，才真正产出 1.1 MB 文件。

## 代价

- 约 30 次工具调用：4 次端口探测、1 次进程采样、1 次日志排查、3 次重启、5 次 agent 鉴权尝试（amr / claude / byok / pi）。
- 1 个完全空转的 run（约 6 分钟）+ 1 次返工 run（约 24 分钟）。
- 一次错误的「已完成」判断差点被直接报给用户。

## 影响面

- 本机所有依赖 open-design 的自动化：daemon 假死后 MCP 只会报 `fetch failed`，不会告诉你原因。
- 所有「agent 自述交付」的流程：`status: succeeded` 只代表 agent 退出码正常，不代表产物存在。
- Claude Code 在本机原本四个内置 agent 全无凭据（amr 未登录、claude 未登录、byok 无 provider、pi 无 key），等于 open-design 开箱不可用。

## 如果重来

1. **先打一次真实 HTTP**，不要只看 `lsof` 有没有在听：`curl -m 5 /api/health` 有 JSON 才算活。
2. **`succeeded` 只当声明**：必须 `find <projectDir> -newermt` 或 `list_files` 验产物，再向用户说完成。
3. **在 prompt 里写死文件契约**：「写入 `<path>`，写完调用 list_files 确认，再回复路径」——比事后追问省一整个 run。
4. 失败时先看 daemon 日志（`.tmp/tools-dev/default/logs/daemon/latest.log`）与 `sample <pid>`，不要先怀疑鉴权。
