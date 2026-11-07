# 057 跳转后仍跟随 + 横屏姿态补偿

- 日期：2026-11-07
- 状态：完成（横屏符号待真机确认）
- 关联：055（上一轮只治了「冻死」，没治「跳转后不跟随」）

## 一、用户报的两个现象，同一个缺口

1. 搜索「北斗」跳过去之后，画面固定住，转手机不动。
2. 竖屏切横屏后，陀螺仪表现还是竖屏那套。

两条都指向同一个事实：**朝向只有一个来源，没有「姿态 + 偏移」这层结构**。

- 055 把 `aim` 改成「切手动」，于是跳转后姿态被主动放弃。用户要的是「跳过去、然后继续跟着转」，手动模式给不了。
- `setAttitude` 直接把姿态写进 `root`，没有考虑画布会随界面方向旋转。竖屏时画布上 == 设备上；横屏时两者差 90°，于是左右转头变成画面上下动。

## 二、改法：朝向 = 画布补偿 × 姿态 × 跳转偏移

```swift
root.orientation = interfaceCompensation * base * aimDelta
```

- `base`：最近一次姿态推出的场景朝向（`attitudeBase`）
- `aimDelta`：跳转产生的偏移，写在设备/星空坐标系里
- `interfaceCompensation`：`Rz(-interfaceRoll)`，界面竖屏 0、横屏 ±90°

三者的关系是「谁先谁后」而不是「谁覆盖谁」，所以不再需要 `aimLocked` 那类互斥锁——055 删掉两把锁之后，这里才有位置放偏移。

- `aim(at:)`：跟随时只更新 `aimDelta`（不动输入源）；手动态仍然直接落朝向。
- `setInterfaceRoll`：变了就重算一次，横竖屏切换即时生效。
- `setFollowsAttitude`：切回跟随时把当前朝向折成 `aimDelta`，画面不跳。
- `SkyView` 在出现与尺寸变化时读 `UIWindowScene.interfaceOrientation`。

## 三、验证

- 319 项测试 0 失败，新增 3 项坐标系测试：
  - `testAimWhileFollowingCentersTargetWithoutLeavingFollow`：跟随时跳转，目标落在中心且输入源仍是跟随
  - `testAimOffsetKeepsFollowingAttitude`：跳转后转手机，视线跟着动（>5°）
  - `testInterfaceRollMapsWorldUpOntoScreenUp`：界面转 90° 后，世界上落到画布长轴
- 真机日志：`sky.orient angle=0` → `sky.aim target=Ori`，之后**没有** `sky.mode` 行，说明跳转没再抢走跟随。

## 四、待真机确认的一件事

横屏补偿的**符号**没法定死。`landscapeLeft` 对应 `-90°` 还是 `+90°` 取决于界面旋转方向的定义，模拟器没有陀螺仪验不了。判定方法：横屏举起手机，把手机向左右各转 30°，画面应当左右平移而不是上下翻滚。若反了，改 `SkySession.setInterfaceOrientation` 里那两个分支的符号即可，一处两行。

日志里每次方向变化都会打 `sky.orient angle=`，真机转一次屏就能看到当前取值。
