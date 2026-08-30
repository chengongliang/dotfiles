#!/usr/bin/env bash
# ============================================================
#  lock.sh — niri 统一锁屏入口（Mod+Alt+L）
#  锁屏后端按机器自动选择：
#  1) 部署了可选的 config/hypr/（Win11 风格 hyprlock 锁屏，
#     见 setup.sh 的 WITH_HYPR 询问）且装有 hyprlock 时，走它；
#  2) 其余情况回退到 noctalia-shell 自带锁屏。
# ============================================================
set -u

HYPR_LOCK_SH="$HOME/.config/hypr/scripts/lock.sh"

if [[ -x "$HYPR_LOCK_SH" ]] && command -v hyprlock &>/dev/null; then
    exec "$HYPR_LOCK_SH"
fi

exec qs -c noctalia-shell ipc call lockScreen lock
