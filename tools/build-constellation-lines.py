#!/usr/bin/env python3
"""生成 31 座之外其余星座的骨架连线。

输入（需要自行下载，不入库）：
  - Sources/Resources/stars.json                  现有星表（含 hip）
  - build/constellations.lines.json               d3-celestial 的星座连线
  - Sources/Features/Sky/Constellations.swift     读取已手工绘制的缩写

输出：
  - Sources/Features/Sky/ConstellationLines.swift

为什么要反查星表而不是直接存坐标：坐标折线只能画线，无法高亮、无法在卡片里
列出成员星、无法和手工那 31 座共用一套数据。d3 的顶点 99.8% 落在 6 等内
恒星上，反查成星名/HIP 后与现有结构完全同构。

星名不够用时用 `#HIP`：星表 2996 颗里 2532 颗没有专名，天兔座 26 颗只有
Arneb、Nihal 两颗有名字，靠星名根本连不起来。

用法：
  curl -sL https://raw.githubusercontent.com/ofrohn/d3-celestial/master/data/constellations.lines.json \
    -o build/constellations.lines.json
  python3 tools/build-constellation-lines.py

数据来源与许可见 THIRD-PARTY.md。
"""

import argparse
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STARS = ROOT / "Sources/Resources/stars.json"
CONSTELLATIONS = ROOT / "Sources/Features/Sky/Constellations.swift"
OUTPUT = ROOT / "Sources/Features/Sky/ConstellationLines.swift"

# d3 的坐标保留 4 位小数，0.02° 约 72 角秒，足够落到唯一一颗 6 等星上。
MATCH_LIMIT_DEGREES = 0.02
# 超过这个角度说明 d3 用了一颗我们星表里没有的暗星，退回最近星并报告。
FALLBACK_LIMIT_DEGREES = 0.35


def unit(ra_hours, dec_degrees):
    ra = ra_hours / 12.0 * math.pi
    dec = dec_degrees * math.pi / 180.0
    return (
        math.cos(dec) * math.cos(ra),
        math.sin(dec),
        -math.cos(dec) * math.sin(ra),
    )


def angular_degrees(a, b):
    dot = max(-1.0, min(1.0, sum(x * y for x, y in zip(a, b))))
    return math.degrees(math.acos(dot))


def load_stars():
    payload = json.loads(STARS.read_text())
    stars = payload["stars"] if isinstance(payload, dict) else payload
    entries = []
    for star in stars:
        if not star.get("hip") and not star.get("name"):
            continue
        key = star["name"] if star.get("name") else "#%d" % star["hip"]
        entries.append({
            "key": key,
            "mag": star["mag"],
            "vector": unit(star["ra"], star["dec"]),
        })
    # 重名星只留最亮的一颗，否则反查会随机落点。
    entries.sort(key=lambda item: item["mag"])
    seen, unique = set(), []
    for entry in entries:
        if entry["key"] in seen:
            continue
        seen.add(entry["key"])
        unique.append(entry)
    return unique


def existing_abbreviations():
    source = CONSTELLATIONS.read_text()
    return set(re.findall(r'abbreviation: "([A-Za-z]+)"', source))


def chinese_names():
    """从 StarFinder.swift 的中文名表读，避免维护两份。"""
    source = (ROOT / "Sources/Features/Sky/StarFinder.swift").read_text()
    block = source.split("enum ConstellationNames", 1)[1]
    return dict(re.findall(r'"([A-Z][A-Za-z]{1,2})": "([^"]+)"', block))


def nearest_star(stars, ra_degrees, dec_degrees):
    vector = unit((ra_degrees % 360) / 15.0, dec_degrees)
    best, best_angle = None, 999.0
    for star in stars:
        angle = angular_degrees(vector, star["vector"])
        if angle < best_angle:
            best, best_angle = star, angle
    return best, best_angle


def build(lines_payload, stars, skip):
    names = chinese_names()
    # 巨蛇座被蛇夫座切成蛇头蛇尾两段，d3 给了两个 Ser feature；
    # 一个星座只能有一个条目，否则列表里会出现两次「巨蛇座」。
    merged, report, kept = {}, [], []
    for feature in lines_payload["features"]:
        abbreviation = feature["id"]
        pairs, keys, worst, broken = [], [], 0.0, False
        for part in feature["geometry"]["coordinates"]:
            previous = None
            for point in part:
                star, angle = nearest_star(stars, point[0], point[1])
                if star is None or angle > FALLBACK_LIMIT_DEGREES:
                    broken = True
                    break
                worst = max(worst, angle)
                if angle > MATCH_LIMIT_DEGREES:
                    report.append((abbreviation, star["key"], angle, star["mag"]))
                if previous and previous != star["key"]:
                    pair = tuple(sorted((previous, star["key"])))
                    if pair not in pairs:
                        pairs.append(pair)
                previous = star["key"]
                keys.append(star["key"])
            if broken:
                break

        # 英仙座有个顶点离星表最近的星也有 1.38°：与其把线接到错误的星上，
        # 不如整座退回手工连线。非手工的座没有退路，只能放宽兜底。
        if broken or (abbreviation in skip and worst > MATCH_LIMIT_DEGREES):
            if abbreviation in skip:
                kept.append((abbreviation, worst))
                continue
            raise SystemExit("%s 的顶点超出 %.2f° 兜底范围" % (abbreviation, FALLBACK_LIMIT_DEGREES))

        slot = merged.setdefault(abbreviation, {"pairs": [], "keys": []})
        for pair in pairs:
            if pair not in slot["pairs"]:
                slot["pairs"].append(pair)
        slot["keys"].extend(keys)

    generated = [
        {
            "abbreviation": abbreviation,
            "name": names.get(abbreviation, abbreviation),
            "pairs": slot["pairs"],
            "stars": len(set(slot["keys"])),
            "hand": abbreviation in skip,
        }
        for abbreviation, slot in merged.items()
    ]
    generated.sort(key=lambda item: item["abbreviation"])
    return generated, report, kept


def emit(generated):
    lines = [
        "// 由 tools/build-constellation-lines.py 生成，勿手改。",
        "// 数据来源：d3-celestial constellations.lines.json（BSD-3-Clause）。",
        "// 顶点按 0.02° 反查星表；无名星以 #HIP 表示。",
        "",
        "extension Constellations {",
        "    /// 88 座骨架，全部来自 d3-celestial 的 IAU 连线。",
        "    /// 手工那 31 座原来各自写 3–10 段，人马座只画出茶壶的壶身，",
        "    /// 看不出射手；统一换成官方骨架后形状才立得住。",
        "    static let detailedLines: [String: [ConstellationLine]] = [",
    ]
    for item in generated:
        body = ", ".join("%s-%s" % pair for pair in item["pairs"])
        lines.append('        "%s": line("%s"),' % (item["abbreviation"], body))
    lines.append("    ]")
    lines.append("")
    lines.append("    /// 31 座手工图形之外的部分，只提供缩写与名字，连线走 detailedLines。")
    lines.append("    static let extended: [Constellation] = [")
    for item in generated:
        if item["hand"]:
            continue
        lines.append(
            '        Constellation(abbreviation: "%s", name: "%s"),'
            % (item["abbreviation"], item["name"])
        )
    lines.append("    ]")
    lines.append("}")
    lines.append("")
    OUTPUT.write_text("\n".join(lines))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lines", default=str(ROOT / "build/constellations.lines.json"))
    args = parser.parse_args()

    path = Path(args.lines)
    if not path.exists():
        raise SystemExit("缺少连线数据：%s\n见本文件头部注释的下载命令。" % path)

    stars = load_stars()
    skip = existing_abbreviations()
    generated, report, kept = build(json.loads(path.read_text()), stars, skip)
    emit(generated)

    total_pairs = sum(len(item["pairs"]) for item in generated)
    hand = [item for item in generated if item["hand"]]
    print("已写出 %s" % OUTPUT.relative_to(ROOT))
    print("%d 座，%d 段（手工 %d 座 / 补全 %d 座）" % (
        len(generated),
        total_pairs,
        len(hand),
        len(generated) - len(hand),
    ))
    if hand:
        print("手工座平均 %.1f 段（原 31 座共 138 段，平均 4.5 段）" % (
            sum(len(item["pairs"]) for item in hand) / len(hand),
        ))
    if report:
        print("用最近星兜底的顶点（>%.2f°）：" % MATCH_LIMIT_DEGREES)
        for abbreviation, key, angle, mag in report[:10]:
            print("  %-4s %-18s %.2f° mag=%.2f" % (abbreviation, key, angle, mag))
    if kept:
        print("退回手工连线（顶点超出 %.2f°）：%s" % (
            MATCH_LIMIT_DEGREES,
            " ".join("%s(%.2f°)" % item for item in kept),
        ))
    empty = [item["abbreviation"] for item in generated if not item["pairs"]]
    if empty:
        print("没有线段：%s" % " ".join(empty), file=sys.stderr)


if __name__ == "__main__":
    main()
