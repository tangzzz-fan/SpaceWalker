# 055 找星跳转后画面冻住：两把锁互堵

- 日期：2026-11-07
- 状态：完成
- 关联：046（重难点 1「朝向三态没定死」）、047–054

## 一、现象

从找星面板点一条结果，跳转过去之后整片天不动了：既不能拖动，转动手机也没有反应。只能退出去重进。

## 二、根因

不是参数写死，是**两把锁互相堵死**：

| 位置 | 逻辑 | 后果 |
|---|---|---|
| `focus(group:)` → `session.aim` | `scene.aim` 把 `aimLocked = true` | 姿态回调被 `guard !aimLocked` 挡掉 |
| `session.drag` | `guard !attitude.isAvailable` | 有陀螺仪就完全不给拖 |
| `setAttitude` | 置 `isAttitudeDriven = true`，**永不复位** | 就算解锁，`apply(rig:)` 也早就被这个标志关掉了 |

三者叠加：姿态不驱动、拖动被禁、手动 rig 也不生效 ⇒ 画面冻死。而且 `aimLocked` 只能靠 `releaseAim()` 解除，而 `releaseAim()` 只在拖动的第一条分支里调用——拖动被禁，就等于永远无法解锁。

046 的重难点 1 预言过这一条：「朝向三态没定死，搬完只是换皮」。当时没修，因为它是行为缺陷而不是搬家；现在它被真实用户踩到了。

## 三、修法：用输入源取代两把锁

`SkyScene` 只认一个事实：

```swift
enum InputSource { case manual, attitude }
var source: InputSource = .manual
```

- `setAttitude(_:)`：`guard source == .attitude`，否则直接返回
- `apply(rig:)`：`guard source == .manual`
- `aim(at:)`：写完朝向就把 `source` 置 `.manual` —— **定位即交还控制权**
- 删掉 `aimLocked` / `isAttitudeDriven` / `releaseAim()`

会话侧给出用户意图：

- `followsAttitude`（意图）+ `isManual`（意图 ∧ 设备能力）
- `aim` → `setFollowsAttitude(false)`，并记 `sky.mode follow=0 manual=1`
- 底栏新增切换按钮（姿态可用时才显示），图标 `hand.draw` / `gyroscope`
- 顶栏文案由能力判断改为意图判断：`手动 · 拖动旋转` / `姿态跟随 · 转动手机环顾`

## 四、验证

- 单测 316 项 0 失败，新增 6 项：`testAimSwitchesSourceToManual`、`testAttitudeSourceIgnoresManualRig`、`testAimRoundTripsWithDrag`（改接口）与 4 项会话模式测试。
- 真机（iPhone 16 Pro）：带 `SPACEWALKER_AIM=Ori` 启动，日志 `[385ms] sky.mode follow=0 manual=1` 紧跟 `sky.aim target=Ori`，说明定位后立刻切到手动，拖动可用。
- 真机截图确认底栏两个按钮并排、文字无截断。

## 五、遗留：跳转后是「锁死」还是「继续跟随」

当前行为：跳转 ⇒ 切手动 ⇒ 转动手机不影响画面，要恢复跟随得按一下陀螺仪按钮。

严格按 AR 语义，更好的做法是**保留跟随、同时加一个朝向偏移**：`root = inverse(devicePose) · aimOffset`，这样跳转后转头仍然能环顾，只是目标的中心位置被对齐。这需要把 `aimOffset` 在定位那一刻从当前姿态算出来，属另一张票。

## 六、顺带发现

`SPACEWALKER_AIM` 这类启动预览在 `field`（恒星时旋转）还没写入时就调用 `aim`，会落到错误方向——本次截图里瞄准 Ori 却停在天龙座。真实找星流程不受影响（用户点击时 field 已就绪），但预览类验收要小心这个竞态。
