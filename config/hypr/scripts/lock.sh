#!/usr/bin/env bash
# ============================================================
#  lock.sh — 锁屏入口
#  作用：把 hyprlock 的壁纸同步成 noctalia 当前正在用的那张，然后锁屏。
#  做法：不改动 hyprlock.conf 本体，而是把标记了 "# NOCTALIA-SYNC" 的
#        那行 path 替换掉，生成一份运行时配置交给 hyprlock -c。
#        这样任何图片格式（jpg/png/webp）都能原样传给 hyprlock。
# ============================================================
set -u

TPL="$HOME/.config/hypr/hyprlock.conf"
OUT="${XDG_RUNTIME_DIR:-/tmp}/hyprlock-live.conf"
STATE="$HOME/.cache/noctalia/wallpapers.json"

current_wallpaper() {
    [ -r "$STATE" ] || return 1
    python3 - "$STATE" <<'PY'
import json, os, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
w = d.get("wallpapers", {}) or {}
def ok(p):
    return p and os.path.isfile(p)
# 1) 优先内置屏；2) 其次任意一块屏；3) 最后兜底默认壁纸
order = [w.get("eDP-1")] + [v for k, v in w.items() if k != "eDP-1"]
for entry in order:
    if not entry:
        continue
    for mode in ("dark", "light"):
        if ok(entry.get(mode)):
            print(entry[mode]); sys.exit(0)
if ok(d.get("defaultWallpaper")):
    print(d["defaultWallpaper"]); sys.exit(0)
sys.exit(1)
PY
}

WP="$(current_wallpaper || true)"

# 模板里用 $HOME 占位；运行时配置是一次性产物，在这里统一展开。
# 壁纸取到就替换标记行，取不到就沿用模板里写死的兜底图。
awk -v wp="${WP:-}" -v home="$HOME" '
    /^[[:space:]]*path[[:space:]]*=.*# NOCTALIA-SYNC/ {
        if (wp != "") { print "    path = " wp; next }
    }
    { gsub(/\$HOME/, home); print }
' "$TPL" > "$OUT"

exec hyprlock -q -c "$OUT"
