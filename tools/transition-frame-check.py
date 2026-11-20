#!/usr/bin/env python3
"""096/NFR-12 逐帧取证：层间转场窗口内不允许出现超过 1 帧的黑帧/白帧，
尺子读数必须单调（下行只减、上行只增）。

用法：
  python3 tools/transition-frame-check.py <session.log> <luminance.csv> --video-start-ms <ms> [--fps 60]

video-start-ms：录屏第 0 帧对应的 app 时钟（session.log 的 [xxxms]）。
冷启动白屏在转场窗口之外，不算违规；窗口由 scale.transition begin/end 界定。
"""
import argparse
import csv
import re
import sys


def parse_transitions(log_path):
    runs = []
    current = None
    with open(log_path) as f:
        for line in f:
            m = re.match(r"\[(\d+)ms\] scale\.transition begin from=(\w+) to=(\w+) token=(\d+)", line)
            if m:
                current = {
                    "t0": int(m[1]), "from": m[2], "to": m[3],
                    "token": int(m[4]), "readings": [],
                }
                continue
            m = re.match(r"\[(\d+)ms\] scale\.transition end from=(\w+) to=(\w+) samples=(\d+) violations=(\d+)", line)
            if m and current:
                current["t1"] = int(m[1])
                current["reported_violations"] = int(m[5])
                # readings 行在 end 之后才写，先入列、继续收集
                runs.append(current)
                continue
            m = re.match(r"\[\d+ms\] scale\.readings\.(\d+)\.\d+ ([\d.e+,]+)", line)
            if m and current and int(m[1]) == current["token"]:
                current["readings"].extend(float(x) for x in m[2].split(","))
    return runs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("csv")
    ap.add_argument("--video-start-ms", type=float, required=True)
    ap.add_argument("--fps", type=float, default=60)
    ap.add_argument("--black-threshold", type=float, default=2.0)
    ap.add_argument("--white-threshold", type=float, default=0.5)
    args = ap.parse_args()

    rows = list(csv.DictReader(open(args.csv)))
    runs = parse_transitions(args.log)
    if not runs:
        print("FAIL: session.log 里没有 scale.transition 记录")
        return 1

    failures = 0
    for run in runs:
        if "t1" not in run:
            print(f"FAIL token={run['token']}: 转场没有 end 记录")
            failures += 1
            continue
        fa = int((run["t0"] - args.video_start_ms) / 1000 * args.fps)
        fb = int((run["t1"] - args.video_start_ms) / 1000 * args.fps)
        window = [r for r in rows if fa <= int(r["frame"]) <= fb]
        black = [int(r["frame"]) for r in window if float(r["meanLuma"]) < args.black_threshold]
        white = [int(r["frame"]) for r in window if float(r["whiteRatio"]) > args.white_threshold]

        def max_run(frames):
            best = cur = 0
            prev = None
            for f in frames:
                cur = cur + 1 if prev is not None and f == prev + 1 else 1
                best = max(best, cur)
                prev = f
            return best

        black_run, white_run = max_run(black), max_run(white)
        order = ["sky", "solar", "earthorbit", "tiangong"]
        descending = order.index(run["to"].lower()) > order.index(run["from"].lower())
        vals = run["readings"]
        violations = sum(
            1 for a, b in zip(vals, vals[1:])
            if (b > a if descending else b < a)
        )
        ok = black_run <= 1 and white_run <= 1 and violations == 0
        status = "PASS" if ok else "FAIL"
        print(
            f"{status} {run['from']}->{run['to']} token={run['token']} "
            f"frames={fa}-{fb} n={len(window)} "
            f"blackRun={black_run} whiteRun={white_run} "
            f"readings={len(vals)} violations={violations} "
            f"(log reported={run.get('reported_violations', '?')})"
        )
        if not ok:
            failures += 1
            if black:
                print(f"  black frames: {black[:12]}")
            if white:
                print(f"  white frames: {white[:12]}")
    print(f"{'ALL PASS' if failures == 0 else str(failures) + ' FAILURES'} ({len(runs)} transitions)")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())