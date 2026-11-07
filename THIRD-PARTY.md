# 第三方内容与许可

本项目代码以 MIT 发布（见 LICENSE）。以下内容例外，或需要单独署名。

## 数据

| 内容 | 来源 | 许可 | 义务 |
|---|---|---|---|
| `Sources/Resources/stars.json`（2996 颗，视星等 ≤ 5.5） | [HYG Database v4.1](https://github.com/astronexus/HYG-Database)（astronexus） | **CC BY-SA 4.0** | 必须署名；修改后的同一数据必须以相同许可分发 |
| `Sources/Resources/asterisms.json`（301 星官 / 814 段连线） | [Stellarium sky cultures · chinese](https://github.com/Stellarium/stellarium-skycultures/tree/master/chinese) | **CC BY-SA**（该文化目录的 `description.md` 单独声明；仓库根为 AGPL，不适用） | 必须署名；修改后的同一数据须以相同许可分发 |
| 恒星专名 | [IAU WGSN](https://www.iau.org/public/themes/naming_stars/) | 公有领域（事实性名称） | 无 |
| HIP 编号桥接（一次性，不入库） | [d3-celestial](https://github.com/ofrohn/d3-celestial) `data/stars.6.json` | BSD-3-Clause | 无（仅用于给现有星表反查 HIP，未分发该文件） |
| 星座骨架连线（88 座，720 段，见 `Sources/Features/Sky/ConstellationLines.swift`） | [d3-celestial](https://github.com/ofrohn/d3-celestial) `data/constellations.lines.json` | **BSD-3-Clause** | 保留版权与免责声明；不得用作者名义为本项目背书 |
| 星座缩写与边界概念 | IAU 88 星座 | 事实性内容 | 无 |

`ConstellationLines.swift` 由 `tools/build-constellation-lines.py` 生成：读 d3-celestial 的 GeoJSON 折线（顶点为 RA/Dec 度数），按 0.02° 反查本地星表，转成星名或 `#HIP`。410 个顶点里 409 个在 0.02° 内命中；英仙座有一个顶点离最近星 1.38°，该座整座退回手工连线。**图形与恒星用同一份 J2000 坐标，因此不会随岁差相对恒星错位。**

`stars.json` 由原始 `hygdata_v41.csv`（约 32MB）过滤生成：剔除太阳、只保留视星等 ≤ 5.5 的恒星，字段 `ra/dec/mag/ci/name/con/hip`。`hip` 由 `tools/build-catalogs.py` 借 d3-celestial 的 6 等星表按坐标反查补齐。

`asterisms.json` 同样由该脚本从 Stellarium 的 `chinese/index.json` 生成：只保留成员星能在本星表中解析到的星官，并把 `lines` 里的 HIP 序列原样带过来。字段含义见 `GLOSSARY.md`。

`fengshen.json` 由 `tools/build-fengshen.py` 生成，名单逐条录自第九十九回原文，以国学大师本为底本、参校文林社本；异体字（蛇/蛟、豸/獬、麞/獐、昂/昴）取规范写法。原文只书「闪电神」「助风神」而未具名，据通行本补，并在 `note` 中注明。

**注意**：CC BY-SA 具有传染性。若要改用闭源专有星表，必须整体替换该文件，不能只改文案。

## 图像

| 内容 | 来源 | 许可 |
|---|---|---|
| `Sources/Resources/galaxy-equirect.jpg` | NASA/Goddard Space Flight Center Scientific Visualization Studio，*Deep Star Maps 2020*（[SVS 4851](https://svs.gsfc.nasa.gov/4851)） | 公有领域（NASA 内容一般不受版权保护） |
| 文档截图 `docs/images/*.png` | 本项目模拟器截图 | MIT |
| `Sources/Resources/constellation-art/*.png`（87 张，覆盖 88 座中的 87 座） | [Stellarium](https://github.com/Stellarium/stellarium) `skycultures/modern/illustrations`，Johan Meuris 绘 | **Free Art License 1.3** | 必须署名作者与许可（界面内已标「星座图 Stellarium / Johan Meuris · Free Art License」）；图片原样分发、未改动像素，故仅需附带许可；若改写图片，改后版本须以 FAL 发布 |

星座插画取自 Stellarium 现代星空文化，原作者 Johan Meuris。南船座拆成船底/船尾/船帆三座后共用同一张整船图，巨蛇座原库未提供单图（蛇夫座抱着两段蛇）。取用时只做了重命名（`sagittarius.png` → `art-Sgr.png`）以便按缩写查找，像素未改。界面里用 `luminanceToAlpha` 把黑底转成透明、线条着色，属于运行时渲染，不产生衍生作品。

**注意**：FAL 是 copyleft。若将来要闭源分发，可以整体替换这 85 张图，不影响代码的 MIT 许可；图片与代码是两个独立作品，聚合分发不传染。

处理方式：原始 `starmap_2020_4k.exr`（OpenEXR 半浮点线性 HDR，34MB）→ CoreImage 曝光 +0.35EV、对比 1.18、饱和 1.15 → sRGB JPEG q84。

不得使用 NASA 标识，也不得暗示 NASA 对本项目的背书。

## 文本

| 内容 | 来源 | 说明 |
|---|---|---|
| 星座释义（88 个星座，西方神话 + 中国星官） | 本项目撰写 | 依据通行天文史与星官体系，非直译受版权保护的文案 |
| `Sources/Resources/fengshen.json`（369 条名讳） | 《封神演义》第九十九回，明代小说，公有领域 | 名号、人物、所属部为原作事实性内容；部门说明、界面文案为本项目撰写，随代码以 MIT 发布 |
| 一百单八将对照（108 条） | 《水浒传》第七十一回石碣天书，明代小说，公有领域 | 星号、绰号、姓名与座次属原作事实性内容 |
| 中文传统星名（127 条） | 中国传统星表 | 事实性名称 |

## 未采用的素材

| 来源 | 内容 | 许可 | 结论 |
|---|---|---|---|
| Stellarium `constellationship.fab` | 星座连线 | GPLv2+ | 未使用，连线为自建 |
| Hevelius / Bode 星图 | 星座版画 | 公有领域 | 仅作造型参考，未直接取用位图 |

## 依赖

| 包 | 用途 | 许可 |
|---|---|---|
| `Packages/TGReduxKit` | 单向数据流与状态切片 | MIT |
| `Packages/TGFeatureFlag` | 功能开关 | MIT |

两者为作者自研库，已裁剪后内嵌于仓库，仅保留 `Package.swift` 与源码。
