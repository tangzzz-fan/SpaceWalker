#!/bin/bash
# 096 层间转场录屏取证。simctl 没有 tap，用一次性 UITest 驱动六段切层，
# 本脚本负责并行录屏、归档 session.log、抽帧并跑 NFR-12 判定。
#
# 用法：tools/record-scale-ladder.sh <UDID> <outdir> [transition-seconds]
# 依赖：已 build 的 SpaceWalker.app + SpaceWalkerUITests（SkyCheck scheme）。
#
# 关键事实（踩过的坑）：
# 1. `xcodebuild test -scheme SkyCheck` 的 shell 环境变量不会传给 runner，
#    SPACEWALKER_RECORD 必须写进 xctestrun 的 TestingEnvironmentVariables。
# 2. `xcodebuild test`（带 build）会顺带跑 SpaceWalker scheme 的单测 target，
#    与录屏并行时把 runner 挤到 watchdog kill；用 test-without-building 只跑指定用例。
# 3. 多显示器模拟器默认录到外接屏，必须显式指定 1206 宽内屏。
set -euo pipefail
UDID="${1:?usage: record-scale-ladder.sh <UDID> <outdir> [seconds]}"
OUT="${2:?outdir}"
TSEC="${3:-0.45}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE=com.tango.xingcha
mkdir -p "$OUT"

XCTESTRUN="$ROOT/DerivedData/Build/Products/SkyCheck_iphonesimulator27.2-arm64.xctestrun"
if [ ! -f "$XCTESTRUN" ]; then
  echo "缺 xctestrun：先 xcodebuild build-for-testing -scheme SkyCheck" >&2
  exit 1
fi

# 把取证环境变量注入 xctestrun（runner + 被测 app 两侧都要）。
# 注意：__TESTROOT__ 相对 xctestrun 所在目录解析，补丁文件必须留在 Products 目录。
PATCHED="$ROOT/DerivedData/Build/Products/SkyCheck-record.xctestrun"
TSEC="$TSEC" python3 - "$XCTESTRUN" "$PATCHED" <<'PY'
import os, plistlib, sys
src, dst = sys.argv[1], sys.argv[2]
d = plistlib.load(open(src, "rb"))
extra = {"SPACEWALKER_RECORD": "1", "SPACEWALKER_TRANSITION_SECONDS": os.environ["TSEC"],
         "SPACEWALKER_TICK_DIAG": "1"}
for name, cfg in d.items():
    if not isinstance(cfg, dict):
        continue
    for key in ("TestingEnvironmentVariables", "UITargetAppEnvironmentVariables"):
        env = cfg.setdefault(key, {})
        env.update(extra)
plistlib.dump(d, open(dst, "wb"))
PY

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
# 测试会重装 app、data 容器路径会变：旧日志清掉，新路径测完再取。
OLD_DATA=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data 2>/dev/null || true)
[ -n "$OLD_DATA" ] && rm -f "$OLD_DATA/Documents/session.log"

DISPLAY_ID=$(xcrun simctl io "$UDID" enumerate 2>/dev/null \
  | awk '/UUID:/{u=$2} /Default width: 1206/{print u; exit}')
[ -n "$DISPLAY_ID" ] || { echo "找不到 1206 宽内屏" >&2; exit 1; }
echo "display=$DISPLAY_ID"
xcrun simctl io "$UDID" recordVideo --force --display "$DISPLAY_ID" --codec=h264 "$OUT/ladder-roundtrips.mp4" &
REC=$!
trap 'kill -INT $REC 2>/dev/null || true' EXIT
sleep 1

cd "$ROOT"
xcodebuild test-without-building \
  -xctestrun "$PATCHED" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:SpaceWalkerUITests/ScaleLadderUITests/testRecordedSixSegmentRoundTrip \
  2>&1 | tee "$OUT/xcodebuild.log" | grep -E "Test Case.*(passed|failed|skipped)|TEST (EXECUTE )?(SUCCEEDED|FAILED)"
grep -q "TEST EXECUTE SUCCEEDED" "$OUT/xcodebuild.log" || { echo "测试未成功，见 $OUT/xcodebuild.log" >&2; exit 1; }
grep -q "Test Case.*testRecordedSixSegmentRoundTrip.*passed" "$OUT/xcodebuild.log" \
  || { echo "取证用例未真正执行（被跳过？）" >&2; exit 1; }

sleep 2
kill -INT $REC 2>/dev/null || true
wait $REC 2>/dev/null || true
trap - EXIT
sleep 2
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

DATA=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)
cp "$DATA/Documents/session.log" "$OUT/session.log"
TRANSITIONS=$(grep -c "scale.transition end" "$OUT/session.log")
[ "$TRANSITIONS" -eq 6 ] || { echo "转场只有 $TRANSITIONS 段，应为 6" >&2; exit 1; }

# 旧帧必须真清空：safe-delete 的 rm 把文件移到回收站目录而非删除，
# 会留下上一轮的高编号帧污染本轮 CSV。用 /bin/rm 清项目内临时取证产物。
/bin/rm -rf "$OUT/frames"
mkdir -p "$OUT/frames"
swiftc -O "$ROOT/tools/extract_frames.swift" -o "$OUT/extract_frames"
"$OUT/extract_frames" "$OUT/ladder-roundtrips.mp4" "$OUT/frames" 60

# 对齐：video-start-ms = 录屏第 0 帧对应的 app 时钟（负值 = app 零点在录屏里的时刻）。
# 用 XCUI「Synthesize event」时间戳与 app 侧 ladder.tap 交叉标定：
#   录屏开始时刻取 mp4 文件 birth；XCUI t=0 取 xcodebuild.log 的 Start Test 时刻；
#   offset = (t0_video + tap_t) * 1000 - app_tap_ms，取六次中位数。
# 注意 recordVideo 文件创建后约 0.5s 才出首帧，birth 比实际首帧早，
# 故再用「画面变化点落入转场窗口」做 ±600ms 精调（画面渐变是转场的直接证据）。
python3 - "$OUT" "$ROOT" <<'PY'
import csv, os, re, statistics, sys
out, root = sys.argv[1], sys.argv[2]
video = f"{out}/ladder-roundtrips.mp4"
birth = os.stat(video).st_birthtime
log = open(f"{out}/xcodebuild.log").read()
m = re.search(r"Start Test at (\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d+)", log)
import datetime
t0 = datetime.datetime.strptime(m[1], "%Y-%m-%d %H:%M:%S.%f").timestamp()
taps_xcui = [float(x) for x in re.findall(r"t =\s+([\d.]+)s\s+Synthesize event", log)]
taps_app = [int(x) for x in re.findall(r"\[(\d+)ms\] ladder\.tap", open(f"{out}/session.log").read())]
assert len(taps_xcui) == len(taps_app) == 6, (len(taps_xcui), len(taps_app))
offsets = [(t0 - birth + tx) * 1000 - ta for tx, ta in zip(taps_xcui, taps_app)]
vs = -statistics.median(offsets)
# 精调：转场窗口内应出现画面亮度变化；在 ±600ms 里找让六段窗口都覆盖变化点的偏移。
rows = list(csv.DictReader(open(f"{out}/frames/luminance.csv")))
luma = [float(r["meanLuma"]) for r in rows]
changes = [i for i in range(1, len(luma)) if abs(luma[i] - luma[i-1]) > 0.3]
runs = []
cur = None
for line in open(f"{out}/session.log"):
    m = re.match(r"\[(\d+)ms\] scale\.transition begin", line)
    if m: cur = [int(m[1])]
    m = re.match(r"\[(\d+)ms\] scale\.transition end", line)
    if m and cur: cur.append(int(m[1])); runs.append(cur); cur = None
def score(v):
    s = 0
    for a, b in runs:
        fa, fb = (a - v) / 1000 * 60, (b - v) / 1000 * 60
        s += sum(1 for c in changes if fa - 6 <= c <= fb + 6)
    return s
best = max((vs + d for d in range(-600, 601, 25)), key=score)
print(f"tapOffsets={[round(o) for o in offsets]} median-vs={vs:.0f} refined-vs={best:.0f} score={score(best)}")
open(f"{out}/video-start-ms.txt", "w").write(f"{best:.0f}")
PY
VS=$(cat "$OUT/video-start-ms.txt")
cp "$OUT/frames/luminance.csv" "$OUT/luminance.csv"
python3 "$ROOT/tools/transition-frame-check.py" "$OUT/session.log" "$OUT/luminance.csv" \
  --video-start-ms "$VS" --fps 60 | tee "$OUT/frame-check.txt"