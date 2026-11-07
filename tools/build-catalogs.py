#!/usr/bin/env python3
"""重建星表与星官表。

输入（需要自行下载，不入库）：
  - Sources/Resources/stars.json        现有星表（HYG 5.5 等，无 HIP）
  - build/stars.6.json                  d3-celestial 6 等星表，仅用于 HIP↔坐标桥接
  - build/chinese_index.json            Stellarium chinese 星空文化的 index.json

输出：
  - Sources/Resources/stars.json        追加 hip 字段
  - Sources/Resources/asterisms.json    318 星官中可解析的部分

用法：
  python3 tools/build-catalogs.py --d3 build/stars.6.json --chinese build/chinese_index.json

数据来源与许可见 THIRD-PARTY.md。
"""

import argparse
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STARS = ROOT / "Sources/Resources/stars.json"
ASTERISMS = ROOT / "Sources/Resources/asterisms.json"

MATCH_LIMIT_DEGREES = 0.02

# Stellarium 数据里三条缺 native 名，pronounce 字段给出了读音
NAME_FALLBACK = {
    "CON chinese 027": "星宿",
    "CON chinese 089": "龟",
    "CON chinese 162": "平",
}


def unit_vector(ra_hours, dec_degrees):
    ra = ra_hours / 24 * 2 * math.pi
    dec = math.radians(dec_degrees)
    return (
        math.cos(dec) * math.cos(ra),
        math.sin(dec),
        -math.cos(dec) * math.sin(ra),
    )


def angular_degrees(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    return math.degrees(math.acos(max(-1.0, min(1.0, dot))))


def load_d3(path):
    payload = json.loads(Path(path).read_text())
    entries = []
    for feature in payload["features"]:
        lon, lat = feature["geometry"]["coordinates"]
        entries.append(
            {
                "hip": feature["id"],
                "ra": (lon % 360) / 15.0,
                "dec": lat,
                "mag": feature["properties"]["mag"],
            }
        )
    return entries


def build_hip_index(entries):
    buckets = {}
    for entry in entries:
        key = int(entry["dec"] // 2)
        buckets.setdefault(key, []).append((entry["hip"], unit_vector(entry["ra"], entry["dec"])))
    return buckets


def nearest_hip(buckets, ra_hours, dec_degrees):
    vector = unit_vector(ra_hours, dec_degrees)
    key = int(dec_degrees // 2)
    best_hip, best_angle = None, 9.0
    for k in (key - 1, key, key + 1):
        for hip, candidate in buckets.get(k, []):
            angle = angular_degrees(vector, candidate)
            if angle < best_angle:
                best_hip, best_angle = hip, angle
    if best_angle > MATCH_LIMIT_DEGREES:
        return None, None
    return best_hip, best_angle


def attach_hip(stars, buckets):
    # 一颗星只认领一个 HIP，一个 HIP 也只被一颗星认领（取角距最小的那颗）
    claims = {}
    for index, star in enumerate(stars):
        hip, distance = nearest_hip(buckets, star["ra"], star["dec"])
        if hip is None:
            continue
        claims.setdefault(hip, []).append((distance, index))

    assigned = {}
    for hip, candidates in claims.items():
        candidates.sort()
        assigned[candidates[0][1]] = hip

    matched = 0
    for index, star in enumerate(stars):
        hip = assigned.get(index)
        star["hip"] = hip
        if hip is not None:
            matched += 1
    return matched


def build_asterisms(chinese_path, hip_set):
    payload = json.loads(Path(chinese_path).read_text())
    result = []
    dropped = 0
    for item in payload["constellations"]:
        name = (item.get("common_name") or {}).get("native") or NAME_FALLBACK.get(item["id"])
        if not name:
            dropped += 1
            continue
        members = []
        lines = []
        for segment in item.get("lines") or []:
            usable = [hip for hip in segment if hip in hip_set]
            for hip in usable:
                if hip not in members:
                    members.append(hip)
            if len(usable) >= 2 and usable[0] != usable[-1]:
                lines.append(usable)
        if not members:
            dropped += 1
            continue
        result.append({"name": name, "id": item["id"], "members": members, "lines": lines})
    return result, dropped


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--d3", required=True, help="d3-celestial stars.6.json")
    parser.add_argument("--chinese", required=True, help="Stellarium chinese index.json")
    args = parser.parse_args()

    global HIP_ENTRIES
    HIP_ENTRIES = load_d3(args.d3)
    buckets = build_hip_index(HIP_ENTRIES)

    catalog = json.loads(STARS.read_text())
    stars = catalog["stars"]
    matched = attach_hip(stars, buckets)

    catalog["source"] = catalog["source"] + " · HIP 编号经 d3-celestial 桥接"
    STARS.write_text(json.dumps(catalog, ensure_ascii=False, indent=1) + "\n")

    hip_set = {star["hip"] for star in stars if star.get("hip")}
    asterisms, dropped = build_asterisms(args.chinese, hip_set)
    payload = {
        "source": "Stellarium chinese sky culture (chinese/index.json)",
        "license": "CC BY-SA",
        "asterisms": asterisms,
    }
    ASTERISMS.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n")

    segments = sum(len(line) - 1 for item in asterisms for line in item["lines"])
    drawable = sum(1 for item in asterisms if item["lines"])
    print(f"星表 {len(stars)} 颗，其中 {matched} 颗有 HIP", file=sys.stderr)
    print(
        f"星官 {len(asterisms)} 个（丢弃 {dropped} 个无可见成员），"
        f"其中 {drawable} 个有连线，线段 {segments} 条",
        file=sys.stderr,
    )


HIP_ENTRIES = []

if __name__ == "__main__":
    main()
