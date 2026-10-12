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

current_wallpaper() {
    # 新版 noctalia（5.x Rust）：优先按输出查询实际生效的壁纸路径。
    local wp
    wp="$(noctalia msg wallpaper-get eDP-1 2>/dev/null || true)"
    if [ -n "$wp" ] && [ -f "$wp" ]; then
        printf '%s\n' "$wp"
        return 0
    fi
    wp="$(noctalia msg wallpaper-get 2>/dev/null || true)"
    if [ -n "$wp" ] && [ -f "$wp" ]; then
        printf '%s\n' "$wp"
        return 0
    fi
    return 1
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
