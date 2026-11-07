# TGFeatureFlag 设计说明

Feature Flag 用于 **解耦部署与发布**、金丝雀放量与 A/B 测试。本库提供两套用法；**Redux / TGReduxKit 应用必须以 Store 为唯一真源（SoT）**。

---

## 1. 双模式

| 模式 | API | SoT | 适用 |
|------|-----|-----|------|
| **Resolver**（推荐 Redux） | `FeatureFlagResolver` → `FeatureFlagSnapshot` | App Store（dispatch 之后） | TGReduxKit 等 |
| **Service**（可选） | `@MainActor @Observable FeatureFlagService` | Service 自身 | Demo / 非 Redux SwiftUI |

**禁止**：在 Redux App 中同时挂 `FeatureFlagService` Environment 与 Store 快照，形成双 SoT。

```text
Providers → FeatureFlagResolver → FeatureFlagSnapshot
         → App Adapter (FeatureFlagFetching)
         → Middleware Effect → .loaded(snapshot, Date)
         → Reducer / crossCutting 投影 → Views
```

TGReduxKit **5.0.1** Shopping demo（`FeatureFlagFetching` + `makeFeatureFlagsMiddleware` + slice / crossCutting）是规范接线；本库对齐其端口形状，**不依赖、不重做 Redux**。

---

## 2. 类型化值

```swift
enum FeatureFlagValue: Sendable, Equatable, Codable {
    case bool(Bool), string(String), int(Int), double(Double)
}
```

- `FeatureFlagKey.defaultValue: FeatureFlagValue`
- Provider / Snapshot / Logger 均使用 `FeatureFlagValue`（无 `Any`、无 resolution `fatalError`）

库侧 `FeatureFlagSnapshot` 是通用 `[String: FeatureFlagValue]`；业务形状的 DTO（如 Shopping 的布尔字段结构体）由 **App 映射**。

### 类型化 key

`TypedFeatureFlag` 让读取直接得到声明的 Swift 类型，`isEnabled` 只接受布尔 key（否则编译报错）：

```swift
enum AppFeature: String, TypedFeatureFlag, CaseIterable {
    case newProfileDesign = "feature_new_profile"
    var typedDefaultValue: Bool { false }
}
let on: Bool = resolver.isEnabled(AppFeature.newProfileDesign)
```

代价是**一个枚举只能有一种值类型**（`Value` 是关联类型）。布尔开关与字符串配置应拆成不同枚举——两者除了都叫「开关」并无共性，拆开通常更好。

`rawValue(for:)` 是保留的弱类型逃生口，供调试工具与 `any FeatureFlagKey` 场景使用。

---

## 3. Redux 接线（App 侧）

与 TGReduxKit 5.0.1 一致：

1. Composition Root 注入 Sendable 的 fetch 端口（Adapter 捕获 `FeatureFlagResolver`）。
2. Middleware 工厂返回 `Effect.task`，调用 `fetchSnapshot()`，再 `dispatch(.loaded(..., now()))`（时间不进 Reducer）。
3. Slice reducer 写 `FeatureFlagsState`；需要时用 parent `crossCuttingReducer` 投影到其他 slice。
4. View 读投影字段或 status slice；可用 `FeatureGate(feature, snapshot:)`，不要用 Environment Service。

```swift
struct TGFFFetchingAdapter: FeatureFlagFetching {
    let resolver: FeatureFlagResolver
    func fetchSnapshot() async -> AppFeatureFlagSnapshot {
        _ = await resolver.refresh()
        let remote = resolver.snapshot(for: AppFeature.allCases)
        return AppFeatureFlagSnapshot(/* map keys */)
    }
}
```

真实远程建议在 Adapter / Middleware 中 `do/catch` → `.loadFailed`（Shopping demo 的 live path 为教具简化）。

---

## 4. 最佳实践

1. **强类型 key**：枚举 + `FeatureFlagKey`，禁止散落字符串。
2. **本地兜底**：每个 flag 必须有 `defaultValue`。
3. **统一 lookupKey**：Grouped 使用 `qualifiedKey`；Debug / Rollout / Local(enabledFeatures) 均写同一 key。
4. **稳定灰度**：`RolloutProvider` 使用 FNV-1a（UTF-8）；0% 返回 `.bool(false)`，不穿透下层。哈希值已被测试用固定向量钉住——改动等于给全体用户重新分桶，必须是有意为之。
5. **优先级平局**：同优先级时**先注册者胜**。注册顺序只用于破平局，永不越过优先级；该契约有测试保护。
6. **清理僵尸开关**：设过期约定，避免长期交叉依赖。
7. **远程驱动灰度**：百分比来自下发文档（`RemoteRolloutProvider`），改灰度不发版；文档整体替换，不在文档里的 flag 停止灰度而不是沿用旧百分比。`value` 支持裸字面量。整数值（`1.0`、`1e3`）会被 `JSONDecoder` 抹掉小数点评为 `int`——因此 `Double` 开关**接受** `int` 并做仅此一例的放宽（上报 `valueWidened`，不回落到默认值）；反向不放宽：`Int` 开关收到 `1.5` 仍是类型不匹配并回落。`1` 也不等于 `true`。
8. **可观测性**：用 `FeatureFlagEventSink` 收事件。曝光按「会话 + flag + 值」去重，每次会话只报一次；`.resolutions` 每次读取都触发，只在调试时开。
9. **冷启动不闪变**：`LastKnownGoodStore` 持久化上次成功快照，启动先喂给 provider 链（远程之下、默认之上）。

---

## 5. SwiftUI

- 非 Redux：`FeatureGate` + `.featureFlagService(_:)`。
- Redux：`FeatureGate(feature, snapshot:)`，snapshot 来自 Store。
- 同一个 `FeatureGate` 支持两种来源；显式传入的 snapshot 优先于环境 Service。
- 调试页 `FeatureFlagDebugView` 同样支持两种来源：Service 模式编辑写入 `DebugProvider`；Redux 模式传 `snapshot: overriddenKeys: onOverride:`，由 App 决定覆盖如何进入 Store（回调收到 `(lookupKey, value)`，`nil` 表示清除覆盖）。显式 snapshot 优先于环境 Service，与 `FeatureGate` 一致；两者皆无时降级为提示而不是 trap。
- 模块划分：`TGFeatureFlagCore`（解析/Provider/Snapshot，**不依赖 SwiftUI**）+ `TGFeatureFlagSwiftUI`（Gate / 调试页）+ `TGFeatureFlag`（聚合再导出）。Core 不依赖 UI 是编译期事实，不是文档约定。

---

## 6. 生命周期提醒

定义 → 远程/本地配置 → 分流 → 监控 → **清理**。开关稳定后应从代码中移除。
