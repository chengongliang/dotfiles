#!/usr/bin/env bash
# 让 magpie 在 niri 下不再自己搬动 quick panel（点托盘图标弹出的小面板）。
#
# 背景：magpie 的 niri 集成（internal/omarchy.NiriPanel）假设 bar 在顶部，
# 面板每次打开都用 MoveFloatingWindow 把它放到「工作区顶部往下 6px、横向贴
# 右侧或点中的图标」，于是 niri 窗口规则（config/niri/cfg/rules.kdl 里的
# magpie panel 规则）定的位置总被覆盖。底部/侧边 bar 是 magpie 的已知限制
# （yetone/magpie#1670）。
#
# 做法：omarchy.Niri() 与 omarchy.niriDial() 都只认 NIRI_SOCKET 环境变量；
# 把二进制里这个变量名换成等长的 MAGPIE_NIRI 后，整套 niri 面板定位逻辑
# 不再启用，面板位置完全交给 niri 的窗口规则（右下角）。
# 等效做法是把 autostart 的 Exec 改成 `env -u NIRI_SOCKET magpie tray`，
# 但那样只在经 autostart 启动时有效，本补丁对所有启动方式都有效。
#
# 用法：
#   ./apply-magpie-no-niri-panel.sh           # 应用（需要 sudo 写 /usr/bin）
#   ./apply-magpie-no-niri-panel.sh --revert  # 还原（用 /usr/bin/magpie.patch-backup）
#
# 生效方式：重启 magpie（托盘菜单 Quit 后重新启动，或重新登录）。
# 注意：magpie 自更新或 `paru -S magpie-bin` 升级会覆盖二进制，重跑本脚本即可。
set -euo pipefail

BIN="${MAGPIE_BIN:-/usr/bin/magpie}"
BACKUP="$BIN.patch-backup"
NEEDLE='NIRI_SOCKET'      # 11 字节
REPLACEMENT='MAGPIE_NIRI' # 必须与 NEEDLE 等长

die() { echo "错误：$*" >&2; exit 1; }

revert() {
    [[ -f "$BACKUP" ]] || die "没有备份 $BACKUP，无法还原（可重装：paru -S magpie-bin）"
    tmp="$(mktemp)"
    cp "$BACKUP" "$tmp"
    sudo install -m 755 "$tmp" "$BIN.new" && sudo mv "$BIN.new" "$BIN"
    rm -f "$tmp"
    echo "已还原 $BIN。重启 magpie 后恢复原行为。"
}

apply() {
    [[ -e "$BIN" ]] || die "$BIN 不存在"
    if ! grep -qa "$NEEDLE" "$BIN"; then
        echo "二进制里已没有 $NEEDLE（补丁已应用或版本已变），跳过。"
        exit 0
    fi
    tmp="$(mktemp)"
    chmod +x "$tmp"
    python3 - "$BIN" "$tmp" "$NEEDLE" "$REPLACEMENT" <<'PY'
import sys
src, dst, needle, repl = sys.argv[1:5]
needle, repl = needle.encode(), repl.encode()
assert len(needle) == len(repl), 'needle 与替换串必须等长'
data = bytearray(open(src, 'rb').read())
i, n = data.find(needle), 0
while i != -1:
    data[i:i + len(needle)] = repl
    n += 1
    i = data.find(needle, i + 1)
open(dst, 'wb').write(data)
print(f'已替换 {n} 处 {needle.decode()}')
PY
    "$tmp" --help >/dev/null || die "补丁后的二进制无法运行，已中止（$BIN 未改动）"
    if [[ ! -f "$BACKUP" ]]; then
        sudo cp "$BIN" "$BACKUP" && sudo chmod 644 "$BACKUP" && echo "原文件已备份到 $BACKUP"
    fi
    sudo install -m 755 "$tmp" "$BIN.new" && sudo mv "$BIN.new" "$BIN"
    rm -f "$tmp"
    echo "已应用补丁：$BIN。重启 magpie 后生效。"
}

case "${1:-}" in
    ""|--apply) apply ;;
    --revert)   revert ;;
    *)          die "未知参数：$1（可用：无参数、--revert）" ;;
esac
