#!/bin/bash
# deepseek-popup.sh — Ctrl+Mod+A 唤起 DeepSeek 快速对话浮窗
#
# 用 Helium 的 --app 模式启动：无地址栏/标签栏的独立窗口，窗口尺寸、右下角
# 定位与圆角由 rules.kdl 里 app-id 前缀 ^chrome-chat\.deepseek\.com 的规则决定。
#
# 登录态：--app 不指定 --user-data-dir，所以复用 ~/.config/net.imput.helium/Default，
# 与主浏览器同一份 cookie，登录一次后长期保持。
#
# 行为（toggle，类似 quake 终端）：
#   没有窗口                → 新建
#   窗口在当前聚焦 workspace → 挪到隔壁空 workspace「收起」，页面状态完整保留
#   窗口在别处/看不见        → 移回当前聚焦 workspace 并聚焦
#
# 收起用「移 workspace」而不是关窗口：Chromium 的 --app 窗口每次启动只会加载
# --app 给的 URL，真关掉再开就回到 DeepSeek 首页、对话和草稿全丢。挪到空
# workspace 后窗口进程仍在，Ctrl+Mod+A 一按即可原样取回（niri 的空 workspace
# 在尾部只保留一个，不会越收越多）。
set -euo pipefail

# Chromium 系 --app 窗口的 app-id 形如 chrome-<host>__-<Profile 目录名>，
# 后缀随 profile 变化（Default / Profile 1 ...），故只比前缀。
APP_ID_PREFIX="chrome-chat.deepseek.com"
URL="https://chat.deepseek.com"

# 输出一行指令：spawn | hide <window_id> <workspace_ref> | show <window_id> <workspace_ref>
ACTION="$(python3 - "$APP_ID_PREFIX" <<'PY'
import json
import subprocess
import sys

prefix = sys.argv[1]


def niri_json(*args):
    proc = subprocess.run(["niri", "msg", "-j", *args], capture_output=True, text=True)
    try:
        return json.loads(proc.stdout or "null") or []
    except json.JSONDecodeError:
        return []


windows = niri_json("windows")
workspaces = niri_json("workspaces")

window = next((w for w in windows if (w.get("app_id") or "").startswith(prefix)), None)
if window is None:
    print("spawn")
    sys.exit(0)

by_id = {w["id"]: w for w in workspaces}
window_ws = by_id.get(window.get("workspace_id"))
if window_ws is None:
    print("spawn")
    sys.exit(0)

# 窗口已经在我当前聚焦的 workspace 里 → 收起
if window_ws.get("is_focused"):
    same_output = [w for w in workspaces if w.get("output") == window_ws.get("output")]
    occupied = {w.get("workspace_id") for w in windows}
    # 优先复用该输出上已有的空 workspace，避免每次收起都新建一个
    empties = [w for w in same_output if w["id"] not in occupied and w["id"] != window_ws["id"]]
    if empties:
        target = max(empties, key=lambda w: w.get("idx") or 0)
        print("hide", window["id"], target.get("name") or target.get("idx"))
    else:
        print("hide", window["id"], max((w.get("idx") or 0) for w in same_output) + 1)
else:
    focused = next((w for w in workspaces if w.get("is_focused")), None)
    if focused is None:
        print("show", window["id"], 1)
    else:
        print("show", window["id"], focused.get("name") or focused.get("idx") or 1)
PY
)"

read -r VERB WID REF <<<"$ACTION"

case "$VERB" in
    spawn)
        # 新窗口由 niri 自动聚焦；脱离终端会话，避免 spawn-sh 退出时被带走
        setsid helium-browser --app="$URL" </dev/null >/dev/null 2>&1 &
        ;;
    hide)
        niri msg action move-window-to-workspace --window-id "$WID" --focus false "$REF"
        ;;
    show)
        niri msg action move-window-to-workspace --window-id "$WID" --focus true "$REF"
        niri msg action focus-window --id "$WID" 2>/dev/null || true
        ;;
esac
