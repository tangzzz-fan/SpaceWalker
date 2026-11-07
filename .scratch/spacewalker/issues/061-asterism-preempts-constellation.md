# 061 星官不再争夺星座的确认权

- 日期：2026-11-07
- 状态：完成
- 关联：059（星官卡）、058（内容分档）、050（仲裁器接线）

## 一、现象

停在猎户座区域识别不出星座，轮廓不及时亮；只有少数星座能高亮。整体比重构前迟钝。

## 二、根因（A/B 对照实测）

| 配置 | 对准猎户座 12 秒 |
|---|---|
| culture=1 | `sky.asterism dwell=参宿` @3.2s，**星座一次都没有** |
| culture=0 | `sky.constellation dwell=Ori` @1.4s |

059 把星官塞进了与星座同一个互斥槽位，并给了更高优先级。猎户座中心必然落在参宿里，
于是每 80ms 的 `clear(.constellation)` 把星座轨道按回零——`advance` 里
`track.target != target` 就重建轨道，`elapsed` 永远到不了 0.6s。

**这是设计错误，不是灵敏度退化。** 星官是「星座里的一组星」，比星座细一级；
两者同槽时细的必然吃掉整体。只有落在星官间隙（`radius + 1°` 之外）的星座才轮得到，
所以表现为「有几个能高亮」。

## 三、修法

星官只在**星座与星群都未命中**时参与确认：

```swift
asterism: (cultureEnabled && constellation == nil && pattern == nil) ? asterism?.name : nil
```

门控下沉到 `SkyScene.Candidates.forAttention(cultureEnabled:showsConstellations:showsPatterns:)`，
可单测，不再散在 View 里。

同时补两件 050 遗留的不一致：

- `constellation` 候选此前不受 `showsConstellations` 门控——关掉星座层仍会识别并弹星座卡。
  现在一并门控：**关掉星座层，星官接管**。这是星官卡该出现的场合。
- `SPACEWALKER_NOCONST=1` 提供无头验收入口，与现有 `SPACEWALKER_*` 一致。

## 四、星官信息不丢

优先级让位不等于功能取消。`AsterismField` 增加 `constellation` 字段（建索引时用中心方向判定），
星座卡多一行回指：

> 星官：参宿 · 伐（附参宿）

截图确认（猎户座卡）：轮廓高亮 + 形状注释 + 星官行 + 23 颗连线星。

## 五、顺手修的隐患

`asterismFields` 原先建在 `guard !segments.isEmpty … else { return }` **之后**——
星表为空或所有星官无连线时，索引整块不建，星官卡静默失效。
现在索引紧接 `starsByHIP` 之后建，与渲染网格成败无关：网格是渲染，索引是查询。

## 六、验收

| 场景 | 结果 |
|---|---|
| 默认（星座层开）AIM=Ori | `sky.constellation dwell=Ori` @1.6s |
| 默认 AIM=UMa | `sky.constellation dwell=UMa` @1.4s |
| 默认 AIM=Ser | `sky.constellation dwell=Ser` @1.6s |
| 默认 AIM=Cyg | `sky.dwell name=Sadr`（星体优先，既有行为） |
| `NOCONST=1` AIM=UMa | `sky.asterism dwell=北斗` |
| `NOCONST=1` + `FLAG_CULTURE=0` AIM=UMa | 无识别日志（两套体系都关，符合预期） |

- 332 项测试 0 失败（新增 5 项：星座压过星官、关层后星官接管、culture 关闭无星官、Ori 携带参宿、空星表索引为空）
- 未做视觉逐像素比对：本轮改的是候选门控与卡片一行，画布渲染路径未动。

## 七、遗留

- 星官卡现在只能通过「关掉星座层」触发。星座内部的星官信息走星座卡那一行。
  若希望「开着星座层也能弹星官卡」，需要一个不互斥的双轨展示（例如长按），不要退回同槽竞争。
