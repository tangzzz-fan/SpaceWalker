# NASA 与第三方素材清单

只记录**实际入库**与**候选待用**两类，避免把素材站收藏夹当资产库。

## 已入库

| 用途 | 来源 | 文件 | 许可 | 处理 |
|---|---|---|---|---|
| 星系天空盒 | NASA/Goddard Space Flight Center Scientific Visualization Studio，《Deep Star Maps 2020》 | `Sources/Resources/galaxy-equirect.jpg`（4096×2048，4.5MB） | 公有领域（NASA 内容一般不受版权保护） | 原始 `starmap_2020_4k.exr`（OpenEXR 半浮点线性 HDR，34MB）→ CoreImage `+0.35EV`、对比 1.18、饱和 1.15 → sRGB JPEG q84 |

原始下载：`https://svs.gsfc.nasa.gov/vis/a000000/a004800/a004851/starmap_2020_4k.exr`
条目页：`https://svs.gsfc.nasa.gov/4851`
致谢要求：NASA/Goddard Space Flight Center Scientific Visualization Studio；Gaia DR2 数据 ESA/Gaia/DPAC。

转换脚本未入库（一次性构建步骤）。若要重跑：用 CoreImage 读取 EXR，调整曝光后经 `CGImageDestination` 写 JPEG。

## 已入库（第三方）

| 用途 | 来源 | 文件 | 许可 | 处理 |
|---|---|---|---|---|
| 恒星数据 | HYG Database v4.1（astronexus） | `Sources/Resources/stars.json`（2996 条，216KB） | **CC BY-SA 4.0** | 原始 `hygdata_v41.csv`（32MB）→ 过滤视星等 ≤ 5.5、剔除太阳 → 只保留 `ra/dec/mag/ci/name/con` |

原始下载：`https://raw.githubusercontent.com/astronexus/HYG-Database/main/hyg/CURRENT/hygdata_v41.csv`
许可：`https://raw.githubusercontent.com/astronexus/HYG-Database/main/hyg/CURRENT/LICENSE`

**CC BY-SA 的传染性要记住**：`stars.json` 是该库的衍生物，必须以同一许可分发并署名。应用内「数据来源」面板已声明；若将来要改成闭源专有数据，必须换源，不能只改文案。

## 使用约束

- 不使用 NASA 标识（"肉丸"与"蠕虫"均为受保护标识），不得暗示 NASA 背书。
- 应用内「素材来源」面板已列出底图与数据来源（`SpaceView.creditsSheet`）。
- 程序化星系（`GalaxyBackground.makeEquirectangular`）保留为兜底：资源缺失或解码失败时仍能出画面。

## 候选待用（未入库）

| 用途 | 来源 | 说明 |
|---|---|---|
| 行星表面贴图 | NASA/JPL Photojournal、USGS Astrogeology | 需要等距柱状投影的行星全球图；优先地球（Blue Marble）、火星、木星 |
| 天宫一号参考 | 中国载人航天工程办公室公开图、CMSA 任务图 | C 阶段造型参考；公开图多为摄影，不能直接当贴图，只作建模依据 |
| 星座连线 | NASA SVS《Deep Star Maps 2020》同系列的 `constellation_figures_4k.tif` | 若做"星座层"，可直接复用同源坐标 |
| 银河带特写 | NASA SVS `milkyway_2020_*` | 与主底图同源，适合做远景切换 |

行星贴图暂不引入：当前用程序化球体 + 非线性压缩半径，先保证"看得懂"；贴图会带来包体与版权核对成本，等 A 阶段体验记录回来再定。
