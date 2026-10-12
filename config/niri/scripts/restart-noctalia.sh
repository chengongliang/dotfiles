#!/bin/sh
# 重启 noctalia（新版 Rust shell）状态栏。
# 应急用：旧版 quickshell 的防抖 Timer 卡死问题在新版已不复存在，
# 但保留该脚本便于遇到异常时快速重启。绑定在 niri keybinds 的 Mod+F12。
set -eu

# -x 精确匹配进程名，避免误杀其他包含 noctalia 字样的进程
pkill -x noctalia || true
sleep 1

# 脱离会话后台启动，日志写到 /tmp 便于排查
setsid noctalia --daemon </dev/null >/tmp/noctalia-restart.log 2>&1 &
