#!/bin/bash
# focus-or-spawn.sh — 如果已有窗口则聚焦，否则启动应用
# Usage: focus-or-spawn.sh <app-id> <command> [resize-width] [resize-height]

if [ $# -lt 2 ]; then
    echo "Usage: $0 <app-id> <command> [resize-width] [resize-height]" >&2
    exit 1
fi

APP_ID="$1"
CMD_NAME="$2"
RESIZE_W="${3:-}"
RESIZE_H="${4:-}"

focus_and_resize() {
    local wid="$1"
    niri msg action focus-window --id "$wid"
    if [ -n "$RESIZE_W" ] && [ -n "$RESIZE_H" ]; then
        sleep 0.1
        niri msg action set-window-width "$RESIZE_W" 2>/dev/null
        niri msg action set-window-height "$RESIZE_H" 2>/dev/null
    fi
}

# 检查是否有可见窗口
WINDOW_ID=$(niri msg --json windows 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data:
    if w.get('app_id') == '$APP_ID':
        print(w['id'])
        break
")

if [ -n "$WINDOW_ID" ]; then
    focus_and_resize "$WINDOW_ID"
    exit 0
fi

# 窗口不可见：同时尝试 D-Bus SNI 激活和 spawn 启动
# SNI 激活对 WeChat 等 Qt 应用很快，spawn 对不支持 SNI 的应（如钉钉）是唯一路径
# 并行执行避免互相等待

# 1) SNI 激活（后台）
(
    SNI_NAME=$(gdbus call --session --dest org.freedesktop.DBus \
        --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.ListNames 2>/dev/null \
        | python3 -c "
import sys, subprocess, re
text = sys.stdin.read()
for name in re.findall(r\"'([^']+)'\", text):
    if not name.startswith('org.kde.StatusNotifierItem-'):
        continue
    try:
        r = subprocess.run(
            ['gdbus', 'call', '--session', '--dest', name,
             '--object-path', '/StatusNotifierItem',
             '--method', 'org.freedesktop.DBus.Properties.Get',
             'org.kde.StatusNotifierItem', 'Id'],
            capture_output=True, text=True, timeout=2
        )
        if '$APP_ID' in r.stdout:
            print(name)
            break
    except:
        pass
")
    if [ -n "$SNI_NAME" ]; then
        gdbus call --session --dest "$SNI_NAME" \
            --object-path /StatusNotifierItem \
            --method org.kde.StatusNotifierItem.Activate 0 0 2>/dev/null
    fi
) &

# 2) spawn（后台）
niri msg action spawn -- "$CMD_NAME" 2>/dev/null || setsid "$CMD_NAME" &>/dev/null &

# 3) 等待窗口出现（来自任一后台路径）
for i in $(seq 1 40); do
    sleep 0.1
    WINDOW_ID=$(niri msg --json windows 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data:
    if w.get('app_id') == '$APP_ID':
        print(w['id'])
        break
")
    if [ -n "$WINDOW_ID" ]; then
        focus_and_resize "$WINDOW_ID"
        exit 0
    fi
done
