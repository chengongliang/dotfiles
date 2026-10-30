#!/bin/sh
# 重启 noctalia（新版 Rust shell）状态栏。绑定在 niri keybinds 的 Mod+F12。
#
# [2026-10-30] 改走 systemd 用户服务：noctalia.service（Restart=always +
# MemoryHigh/MemoryMax 护栏），定义见 dotfiles/config/systemd/user/。
#
# 旧实现的问题：`setsid noctalia --daemon` 虽然脱离了会话，但 cgroup 仍继承
# 调用者 —— 从终端里跑就会落在该终端的 app scope（实测 app-niri-ghostty-*.scope），
# 关掉那个窗口 systemd 会连带杀掉整个 scope，状态栏跟着消失。
# 走 systemctl 则固定落在 app.slice/noctalia.service，与调用者无关。
set -eu

if systemctl --user cat noctalia.service >/dev/null 2>&1; then
    systemctl --user restart noctalia.service
    exit 0
fi

# 回退：service 尚未部署（新机器还没跑 setup.sh 的 stow 阶段）时裸启动。
# -x 精确匹配进程名，避免误杀其他包含 noctalia 字样的进程。
echo "警告：noctalia.service 未部署，回退到裸启动（建议跑 setup.sh 或 stow）" >&2
pkill -x noctalia || true
sleep 1
setsid noctalia --daemon </dev/null >/tmp/noctalia-restart.log 2>&1 &
