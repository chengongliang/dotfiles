#!/usr/bin/env bash
# 给 noctalia-shell 的 clipper 插件打上「按 / 或 f 聚焦搜索框」补丁。
#
# 背景：clipper 来自 Noctalia 官方插件源，插件市场会把它下载（并覆盖）到
# ~/.config/noctalia/plugins/clipper/。插件升级/重装后本地修改会丢失，
# 重新执行本脚本即可恢复。
#
# 用法：
#   ./apply-clipper-search-focus.sh            # 默认插件目录
#   ./apply-clipper-search-focus.sh <目录>      # 自定义 clipper 插件目录
#
# 生效方式：补丁只改 QML 文件，需要让 noctalia-shell 重新加载插件
# （重启 noctalia-shell，例如找终端执行 `pkill -x qs && qs -c noctalia-shell &`）。
set -euo pipefail

PLUGIN_DIR="${1:-$HOME/.config/noctalia/plugins/clipper}"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/clipper-search-focus.patch"
MARKER="clipper-search-focus"

if [[ ! -d "$PLUGIN_DIR" ]]; then
    echo "找不到 clipper 插件目录：$PLUGIN_DIR" >&2
    echo "请先在 Noctalia 插件市场安装 clipper，或用参数指定插件目录。" >&2
    exit 1
fi

if [[ ! -f "$PLUGIN_DIR/Panel.qml" ]]; then
    echo "缺少 $PLUGIN_DIR/Panel.qml，插件结构可能已变化。" >&2
    exit 1
fi

if [[ ! -f "$PATCH_FILE" ]]; then
    echo "找不到补丁文件：$PATCH_FILE" >&2
    exit 1
fi

if grep -q "$MARKER" "$PLUGIN_DIR/Panel.qml"; then
    echo "补丁已存在，跳过：$PLUGIN_DIR/Panel.qml"
    exit 0
fi

if patch -d "$PLUGIN_DIR" -p1 --dry-run -N --silent < "$PATCH_FILE"; then
    patch -d "$PLUGIN_DIR" -p1 -N --silent < "$PATCH_FILE"
    echo "补丁已应用：$PLUGIN_DIR/Panel.qml"
    echo "重启 noctalia-shell 后生效（例如：pkill -x qs && qs -c noctalia-shell &）。"
else
    echo "补丁无法直接应用 —— clipper 版本可能已更新。" >&2
    echo "请参照 $PATCH_FILE 手动合并到 $PLUGIN_DIR/Panel.qml：" >&2
    echo "  在 root 的 Keys 处理区域（Keys.onDigit8Pressed 之后）加入 / 与 f 的聚焦逻辑。" >&2
    exit 1
fi
