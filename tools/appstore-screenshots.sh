#!/usr/bin/env bash
# 星槎 App Store 截图采集（票 082）：Pro Max 模拟器无头启动 6 个画面，
# simctl io screenshot 直出竖屏 PNG，归档到 docs/design/appstore-screenshots/。
#
#   tools/appstore-screenshots.sh            # 全部 6 张
#   tools/appstore-screenshots.sh 1 5        # 只拍第 1、5 张
#
# 前置：xcodegen generate 后先 build 一次模拟器包（脚本会自动 build）。
#
# 尺寸分档（2026-11-17 修正，依据 SportsHelper .scratch/appstore/tools/compose.py
# 的实测结论）：ASC 必需档是「iPhone with Dynamic Island (medium)」——
# iPhone 18 Pro / 17 Pro / 16 Pro，收 1179×2556 与 1206×2622；
# 1320×2868 属 large 档（Pro Max / Air），是可选档。
# 默认在 iPhone 18 Pro 上采 1206×2622（必需）；
# SPACEWALKER_SHOT_DEVICE="iPhone 18 Pro Max" 再采 1320×2868（可选备用）。
# 模拟器截图分辨率以 simctl 实报为准，不缩放伪造。
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="com.tango.xingcha"
DEVICE_NAME="${SPACEWALKER_SHOT_DEVICE:-iPhone 18 Pro}"
OUT_DIR="${SPACEWALKER_SHOT_OUT:-$PROJECT_DIR/docs/design/appstore-screenshots}"
DD="$PROJECT_DIR/build-sim-appstore"
WAIT_BUILD="${SPACEWALKER_SHOT_SKIP_BUILD:-0}"

cd "$PROJECT_DIR"

UDID="$(xcrun simctl list devices available | grep "$DEVICE_NAME (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
if [[ -z "$UDID" ]]; then
  echo "找不到可用模拟器：$DEVICE_NAME（用 SPACEWALKER_SHOT_DEVICE 指定）" >&2
  exit 1
fi

if [[ "$WAIT_BUILD" != "1" ]]; then
  echo "== build（模拟器 Debug）"
  xcodebuild -project SpaceWalker.xcodeproj -scheme SpaceWalker \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DD" build >/tmp/appstore-shots-build.log 2>&1 || {
      tail -20 /tmp/appstore-shots-build.log; exit 1; }
fi
APP="$(find "$DD/Build/Products" -maxdepth 2 -name 'SpaceWalker.app' | head -1)"
[[ -n "$APP" ]] || { echo "找不到模拟器产物" >&2; exit 1; }

xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1
# 状态栏统一 9:41 / 满电（App Store 惯例，同 SportsHelper shoot_store.py）
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 >/dev/null 2>&1
xcrun simctl install "$UDID" "$APP"
# 今夜对齐需要定位授权；模拟器预授，避免授权弹窗挡住截图（真机不适用）
xcrun simctl privacy "$UDID" grant location "$BUNDLE_ID" 2>/dev/null
mkdir -p "$OUT_DIR"

# 画面表：编号|文件名|启动参数（SPACEWALKER_ 前缀省略）
SHOTS=(
  "1|01-sky-orion|MODE=sky AIM=Ori CONSTELLATION=Ori SKYMOTION=0 LAYERS=1"
  "2|02-sky-asterisms|MODE=sky LAYERS=1 NOCONST=1 SKYMOTION=0 AIM=Vega FOV=70"
  "3|03-sky-aligned|MODE=sky ALIGN=1 LAT=39.9 LON=116.4 SKYMOTION=0 FOV=70"
  "4|04-solar|MODE=solarSystem"
  "5|05-tiangong-separated|MODE=tiangong TG_SEPARATED=lab,resource,leftWing,rightWing TG_SELECT=lab TG_FREEZE=1"
  "6|06-tiangong-cutaway|MODE=tiangong TG_CUTAWAY=1"
)

WANTED=("$@")
want() { [[ ${#WANTED[@]} -eq 0 ]] && return 0; local n; for n in "${WANTED[@]}"; do [[ "$n" == "$1" ]] && return 0; done; return 1; }

for entry in "${SHOTS[@]}"; do
  IFS='|' read -r num name params <<<"$entry"
  want "$num" || continue
  echo "== [$num] $name"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null
  env_args=()
  for kv in $params; do env_args+=("SIMCTL_CHILD_SPACEWALKER_${kv%%=*}=${kv#*=}"); done
  env "${env_args[@]}" xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
  sleep 9   # 场景建模约 0.7s，留足渲染与字体加载；再入等动态画面由人工另录
  xcrun simctl io "$UDID" screenshot "$OUT_DIR/$name.png" >/dev/null 2>&1
  python3 - "$OUT_DIR/$name.png" <<'PY'
import struct, sys
p = sys.argv[1]
with open(p, 'rb') as f:
    d = f.read(33)
w, h = struct.unpack('>II', d[16:24])
print(f"   {p.split('/')[-1]}: {w}x{h}")
PY
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null
echo "== 完成，归档于 $OUT_DIR"
echo "   人工步骤：核对画面构图 → 挑选/排序 → （可选加文案框）→ ASC 上传"