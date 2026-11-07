# 内嵌依赖

这两个包是作者自研库，为「clone 即可构建」内嵌在此，不随 CocoaPods/SPM 远端分发。

| 目录 | 用途 | 许可 |
|---|---|---|
| `TGReduxKit` | 单向数据流、状态切片 | MIT |
| `TGFeatureFlag` | 功能开关、调试面板 | MIT |

均只保留 `Package.swift` 与 `Sources/`，剔除各自仓库中的构建产物（`.build` 曾占 247 MB）、示例与 CI 配置。上游若有更新，用同样的裁剪方式覆盖，并同步 `CHANGELOG.md`。

`project.yml` 通过相对路径引用：`Packages/TGReduxKit`、`Packages/TGFeatureFlag`。

## 相对上游的改动

| 文件 | 改动 | 原因 |
|---|---|---|
| `TGFeatureFlag/Package.swift` | 删去 `TGFeatureFlagTests` 测试目标 | 测试目录未内嵌，SPM 会把 `Sources/` 判为重叠源码而无法解析 |
| `TGFeatureFlag/LICENSE` | 新建（MIT） | 上游仓库无 LICENSE 文件，README 只写「See repository license file」 |

`TGReduxKit` 的 `Tests/`（12 KB）予以保留，`Package.swift` 不需要改。
