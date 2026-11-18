#!/usr/bin/env python3
"""087：给 464 颗有专名的星补 HYG v4.1 距离（光年），不重建全表。

取数（一次性，不入库）：
  curl -L -o build/hygdata_v41.csv \\
    https://raw.githubusercontent.com/astronexus/HYG-Database/main/hyg/CURRENT/hygdata_v41.csv
  版本：HYG v4.1（hygdata_v41.csv，33,932,548 字节）；许可 CC BY-SA 4.0。

匹配规则：
  1. 优先 hip 精确匹配；
  2. 无 hip 或 hip 未命中时，按 J2000 坐标匹配（容差 0.05°，取最近）；
  3. HYG 的 dist=100000 是「未知/超出视差量程」占位值，视为缺失，不写入；
  4. 缺失的星不写 dist 字段（不补 0、不补猜测值），名单打印到 stdout。

红线：总星数 2996、视星等 ≤4.5 共 925、有专名 464，三个数字不得漂移。
用法：python3 tools/add-star-distances.py --hyg build/hygdata_v41.csv
"""

import argparse
import bisect
import csv
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STARS = ROOT / "Sources/Resources/stars.json"
MATCH_TOLERANCE_DEGREES = 0.05
DIST_PLACEHOLDER = 100000.0


def load_hyg(path):
    rows = []
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            try:
                ra = float(row["ra"]) * 15.0
                dec = float(row["dec"])
            except ValueError:
                continue
            try:
                dist = float(row["dist"])
            except ValueError:
                dist = None
            rows.append((ra, dec, dist, row["hip"].strip()))
    rows.sort(key=lambda r: r[1])
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--hyg", required=True)
    args = parser.parse_args()

    rows = load_hyg(args.hyg)
    decs = [r[1] for r in rows]
    by_hip = {int(r[3]): r for r in rows if r[3]}

    def match_pos(ra_hours, dec_degrees):
        ra = ra_hours * 15.0
        lo = bisect.bisect_left(decs, dec_degrees - MATCH_TOLERANCE_DEGREES)
        hi = bisect.bisect_right(decs, dec_degrees + MATCH_TOLERANCE_DEGREES)
        best, best_sep = None, MATCH_TOLERANCE_DEGREES
        for r in rows[lo:hi]:
            dra = abs(r[0] - ra) % 360.0
            dra = min(dra, 360.0 - dra) * math.cos(math.radians(dec_degrees))
            sep = math.hypot(dra, r[1] - dec_degrees)
            if sep < best_sep:
                best, best_sep = r, sep
        return best

    catalog = json.loads(STARS.read_text())
    stars = catalog["stars"]
    assert len(stars) == 2996, f"总星数漂移：{len(stars)}"
    named = [s for s in stars if s.get("name")]
    assert len(named) == 464, f"专名星数漂移：{len(named)}"
    assert sum(1 for s in stars if s["mag"] <= 4.5) == 925, "≤4.5 星数漂移"

    filled, missing = 0, []
    for s in stars:
        s.pop("dist", None)
        if not s.get("name"):
            continue
        rec = by_hip.get(s.get("hip") or -1) or match_pos(s["ra"], s["dec"])
        dist = rec[2] if rec else None
        if dist is None or dist <= 0 or dist >= DIST_PLACEHOLDER:
            missing.append(s["name"])
            continue
        s["dist"] = round(dist * 3.26156, 2)
        filled += 1

    catalog["source"] = (
        "HYG Database v4.1 · HIP 编号经 d3-celestial 桥接 · "
        "dist 为专名星距离（光年，HYG v4.1 视差换算，100000 pc 占位值视为缺失）"
    )
    STARS.write_text(json.dumps(catalog, ensure_ascii=False, indent=1) + "\n")

    print(f"filled {filled}/464; missing {len(missing)}:")
    for name in missing:
        print(f"  - {name}")


if __name__ == "__main__":
    main()