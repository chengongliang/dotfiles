#!/bin/sh
# 重启 noctalia-shell 状态栏。
# 状态栏长时间运行后可能出现滚轮切换工作区等交互失效（防抖 Timer 状态卡死），
# 重启即可恢复。绑定在 niri keybinds 的 Mod+F12。
set -eu

# 精确匹配 noctalia-shell 实例（[q]s 防止杀掉执行本脚本的 sh 本身）
pkill -f '[q]s -c noctalia-shell' || true
sleep 1

# 脱离会话后台启动，日志写到 /tmp 便于排查
setsid qs -c noctalia-shell </dev/null >/tmp/noctalia-restart.log 2>&1 &
