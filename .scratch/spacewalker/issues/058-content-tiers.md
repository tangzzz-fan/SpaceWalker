# 058 内容按三档释出（feature flag）

- 日期：2026-11-07
- 状态：完成（接线与门控；释出节奏待运营定）
- 关联：PRD §7.3、ADR-0002（三阶段）

## 一、为什么按「档」而不是按「功能」

一内容一 flag 会得到十几个开关，没有人能说清「现在用户看到的是什么版本」。按认知负荷分三档，每档是一组能被同一句话描述的内容：

| 档 | 内容 | 默认 | 理由 |
|---|---|---|---|
| base | 星表、星座连线、准星选中、恒星卡 | 常开，无开关 | 缺了产品不成立 |
| culture | 星官连线、星座释义、封神星榜 | 开 | 当前体验，用户已在用 |
| deep | 星群、今夜导览、水浒对照 | 关 | 一次全给会手忙脚乱 |

## 二、实现

- `AppFeature` 增加 `contentCulture` / `contentDeep`，默认值就写在枚举里，远端可覆盖。
- `FeatureFlags` 结构体加两个字段；`AppMiddleware` 解析时打一条 `app.flags culture=1 deep=0`，便于事后对账。
- **本地覆盖**：`SPACEWALKER_FLAG_CULTURE=0/1`、`SPACEWALKER_FLAG_DEEP=0/1` 优先于远端快照，验收不必改配置。
- 门控点：底栏「星官」按钮（culture）、星座菜单里的「星群」（deep）、找星面板的「封神星榜」入口（culture）、封神榜的「一百单八将」入口与每条记录的水浒行（deep）、顶栏统计里的「301 个星官」（culture）。

## 三、验证

三组启动分别得到预期取值：

```
默认        app.flags culture=1 deep=0
FLAG_DEEP=1 app.flags culture=1 deep=1
FLAG_CULTURE=0 app.flags culture=0 deep=0
```

`cultures=0` 时截图确认底栏「星官」消失、顶栏统计不再报星官数；321 项测试 0 失败。

## 四、没有做的两件事

- **远端 provider 未接**。`TGFeatureFlag` 里有 `RemoteRolloutProvider`，但 app 目前只用本地 resolver。要「不发版就能开内容」，得先定载体（内置 JSON 只在改包时生效）。
- **从关到开没有提示**。用户不会知道多了什么。建议加一次性角标，用 UserDefaults 记上次看到的档位。

## 五、释出节奏建议

先 base 跑一周看留存与崩溃，再开 culture，最后开 deep。每次只动一档，任何一档出问题都能单独回滚。
