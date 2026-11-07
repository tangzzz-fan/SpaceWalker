#!/usr/bin/env bash
# SpaceWalker 真机工具：跟随日志 / 截屏 / 装包启动。
#
#   tools/device.sh log [--interval 2] [--once] [--grep sky]
#   tools/device.sh shot [输出路径]
#   tools/device.sh run [--build] [--no-layers]
#
# 设备用第一条「有线连接」的真机；多台时用 SPACEWALKER_UDID 指定。
set -uo pipefail

BUNDLE_ID="com.tango.spacewalker"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$PROJECT_DIR/build/Build/Products/Debug-iphoneos/SpaceWalker.app"
UDID="${SPACEWALKER_UDID:-}"

resolve_udid() {
  [[ -n "$UDID" ]] && return 0
  local json
  json="$(mktemp -t spacewalker-devices)"
  xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1
  UDID="$(python3 - "$json" <<'PY'
import json, sys
try:
    payload = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for device in payload.get("result", {}).get("devices", []):
    props = device.get("properties", {})
    connection = props.get("connection", {})
    if connection.get("state") == "connected" and connection.get("transportType") == "wired":
        print(props.get("hardware", {}).get("udid", ""))
        break
PY
)"
  rm -f "$json"
  if [[ -z "$UDID" ]]; then
    echo "没找到用数据线连着的真机（模拟器不算）。接上 iPhone 再试。" >&2
    return 1
  fi
}

cmd_log() {
  local interval=2 once=0 filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --interval) interval="$2"; shift 2 ;;
      --once) once=1; shift ;;
      --grep) filter="$2"; shift 2 ;;
      *) echo "未知参数：$1" >&2; return 1 ;;
    esac
  done
  resolve_udid || return 1

  local tmp dest offset=0 size
  tmp="$(mktemp -d -t spacewalker-log)"
  dest="$tmp/session.log"
  echo "设备 $UDID · 跟随 Documents/session.log（Ctrl-C 退出）" >&2

  while true; do
    if xcrun devicectl device copy from --device "$UDID" \
        --domain-type appDataContainer --domain-identifier "$BUNDLE_ID" \
        --source Documents/session.log --destination "$dest" >/dev/null 2>&1; then
      size="$(wc -c <"$dest" | tr -d ' ')"
      if (( size < offset )); then
        offset=0
        echo "… 日志被重置，从头读 …" >&2
      fi
      if (( size > offset )); then
        if [[ -n "$filter" ]]; then
          tail -c +$((offset + 1)) "$dest" | grep --line-buffered -E "$filter"
        else
          tail -c +$((offset + 1)) "$dest"
        fi
        offset="$size"
      fi
      if (( once == 1 )); then break; fi
    else
      echo "… 拿不到日志（锁屏 / 未安装 / 未启动）…" >&2
      if (( once == 1 )); then rm -rf "$tmp"; return 1; fi
    fi
    sleep "$interval"
  done
  rm -rf "$tmp"
}

cmd_shot() {
  local out="${1:-/tmp/spacewalker-device-$(date +%H%M%S).png}"
  resolve_udid || return 1
  xcrun devicectl device capture screenshot --device "$UDID" --destination "$out" >/dev/null || return 1
  echo "$out"
}

cmd_run() {
  local build=0 layers=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --build) build=1; shift ;;
      --no-layers) layers=0; shift ;;
      *) echo "未知参数：$1" >&2; return 1 ;;
    esac
  done
  resolve_udid || return 1

  if (( build == 1 )) || [[ ! -d "$APP_PATH" ]]; then
    echo "编译真机包…" >&2
    (cd "$PROJECT_DIR" && xcodebuild -project SpaceWalker.xcodeproj -scheme SpaceWalker \
      -destination 'generic/platform=iOS' -derivedDataPath build build >/dev/null) || {
      echo "编译失败" >&2
      return 1
    }
  fi

  xcrun devicectl device install app --device "$UDID" "$APP_PATH" >/dev/null || return 1
  local env_json='{"SPACEWALKER_MODE":"sky","SPACEWALKER_FPS":"1"}'
  if (( layers == 1 )); then
    env_json='{"SPACEWALKER_MODE":"sky","SPACEWALKER_FPS":"1","SPACEWALKER_LAYERS":"1"}'
  fi
  xcrun devicectl device process launch --device "$UDID" \
    --environment-variables "$env_json" "$BUNDLE_ID" >/dev/null || return 1
  echo "已在 ${UDID} 启动，layers=${layers}。跟日志：tools/device.sh log --grep sky" >&2
}

case "${1:-log}" in
  log) shift; cmd_log "$@" ;;
  shot) shift; cmd_shot "$@" ;;
  run) shift; cmd_run "$@" ;;
  *) echo "用法：tools/device.sh {log|shot|run} [参数]" >&2; exit 1 ;;
esac
