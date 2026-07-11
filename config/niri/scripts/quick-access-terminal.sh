#!/bin/bash
# quick-access-terminal.sh — 在当前聚焦显示器上切换 Kitty Quake 终端
#
# Wayland 的 layer-shell 只能在创建时绑定 output，创建后无法迁移。
# 因此为每个显示器维护独立的 instance-group，按 niri 当前聚焦输出切换。

set -euo pipefail

OUTPUT="$(niri msg -j focused-output 2>/dev/null | jq -r '.name // empty')"
if [[ -z "$OUTPUT" || "$OUTPUT" == "null" ]]; then
    # 回退：不指定 output，让 compositor 自行选择
    exec kitten quick-access-terminal
fi

exec kitten quick-access-terminal \
    --instance-group "quick-access-${OUTPUT}" \
    -o "output_name=${OUTPUT}"
