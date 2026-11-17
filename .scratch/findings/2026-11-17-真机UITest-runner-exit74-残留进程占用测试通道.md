# 真机 XCUITest runner exit 74：残留进程占用 IDE 测试通道

日期：2026-11-17 · 场景：084 D7 真机全链取证，SkyCheck scheme 真机跑 ChromeFeedbackUITests

## 现象

- `xcodebuild test -destination 'platform=iOS,id=…'` 连续 3 次失败：
  `SpaceWalkerUITests-Runner … exited with code 74 before establishing connection`
- 无线连接时失败 → 插线（connected）后**仍失败** → 排除「无线不稳定」假设
- `devicectl diagnose` 也报错（DiagnoseError 0），无崩溃报告、设备存储充足

## 排查链（第一性原理）

1. 手动 `devicectl install` runner + `process launch` → **启动成功且进程存活**
   → 签名/安装/entitlement 全部正常，问题不在包本身
2. 抓 xcodebuild 日志关键行：`Exiting due to IDE disconnection.`
   → runner 是被 IDE 通道断开杀掉的，不是自身崩溃
3. 查设备进程表：发现**上一轮失败测试残留的 runner（59791）与 App（59755）仍在运行**
   → 假设：残留 runner 占用 XCTest IDE 通道，新 runner 连不上即被断
4. terminate 全部 SpaceWalker 相关进程后重跑 → **一次通过**（15.8s）
5. 再清场跑全部四条 → 全过（12.8/14.7/11.4/9.4s）→ 假设证实

## 本质

**exit 74 = 残留 UITest runner 进程占用 IDE 测试通道**，新 runner 建立连接失败被断开。
与有线/无线无关；失败一次后若不杀残留进程，后续必连败（自我强化）。

## 固化对策

真机跑 XCUITest 前（尤其上次失败后），先清场：

```bash
xcrun devicectl device info processes --device "$UDID" --json-output /tmp/p.json
# terminate 所有 executable 含 SpaceWalker 的进程（App + Runner）
```

已纳入 084 票实施记录；tools/device.sh 后续可加 `clean` 子命令（未做，登记）。

## 教训

- 「code 74 before establishing connection」先查**设备端残留进程**，再怀疑连接方式
- 手动 launch runner 是区分「包问题 vs 通道问题」的最快判据