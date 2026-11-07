# 贡献指南

## 提交前

```bash
xcodebuild test -project SpaceWalker.xcodeproj -scheme SpaceWalker \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

测试必须全绿。改变渲染、拾取或对齐逻辑时，附带一张模拟器截图或一段真机日志。

## 内容类改动

内容（星座释义、星官名、封神名号、连线、图形轮廓）必须能被测试校验，不接受「看起来对」：

| 内容 | 必须满足 |
|---|---|
| 星座连线 / 图形轮廓 | 引用的星名必须存在于 `stars.json`；图形要包含它声明的锚点星 |
| 星官名 | 能被 `AsterismParser` 解析成「星官 + 序号」，或显式列入映射表 |
| 星座释义 | 每个有连线的星座都要有，长度有下限（防占位符） |
| 封神名号 | 28 宿齐全，水火二部各 4 人，人名异说要在文案里说明 |
| 中文星名 | 只收录有据可查的名称；IAU 正式名与传统文化名分开标注 |

## 引用与许可

- 星表：HYG v4.1，CC BY-SA 4.0，改动后仍以同许可分发
- 图像：只用公有领域或明确授权的素材，登记到 `THIRD-PARTY.md`
- 不要引入 GPL / Free Art License 的星座美术图或连线文件

## 代码约定

- 生产代码不写注释；测试与文档写清楚「为什么」
- 新增调试入口统一放 `LaunchMode`，用 `SPACEWALKER_` 前缀
- 修改拾取路径时，确认 `sky.pickProbe` 仍然全部取回自身：探针会跟着错误实现一起自洽，必须按渲染真实位置构造
- 姿态与地平是两层旋转（`root` 与 `field`），任何从局部坐标到世界坐标的换算都要显式经过 `field`
