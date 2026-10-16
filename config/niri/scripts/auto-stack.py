#!/usr/bin/python3
"""niri 自动堆叠（auto-stack）：新开的同类终端窗口自动并入相邻的同类终端列。

背景：niri 里新窗口永远作为新列开在当前列的右侧（官方 FAQ
"Can I open a window directly in the current column?" → No），所以连续开两个
alacritty 默认是左右并排，而不是上下堆叠。想要堆叠必须打开后再
consume 进某一列（`Mod+Ctrl+T` 手动做这件事）。

本脚本监听 niri IPC 事件流，在新窗口出现后检查它相邻的列
（layout.pos_in_scrolling_layout 的 col ± 1）：
  * 左邻列里有 STACK_APP_IDS 中的 app → `consume-or-expel-window-left --id`
  * 否则右邻列里有 → `consume-or-expel-window-right --id`
两者都没有时保持 niri 原生行为（新窗口独立成列）。

判定细节：
  * 只处理事件流里首次出现的新窗口；连接时的既有窗口、配置重载后的全量
    快照、重连后的窗口都不处理。
  * app_id 还没上报的窗口先跳过，等后续事件补齐再判断。
  * 浮动窗口跳过。
  * 只在「新窗口仍是自己那一列的唯一窗口」时才动手：对已经在多窗口列里的
    窗口再执行 consume-or-expel 会把它 expel 出来，和用户手动
    `Mod+Ctrl+T` 的操作打架（脚本的等待窗口期正好可能撞上）。
  * 用 --id 指定窗口，不读也不改焦点，所以不会抢走你正在用的窗口的焦点。

暂停：touch /tmp/niri-auto-stack.off（删除即恢复）。

由 systemd 用户服务 niri-auto-stack.service 启动（Restart=always），脚本自身
会重连事件流；单实例锁避免重复运行。事件流用法同 scripts/dynamic-float.py。
"""

import fcntl
import glob
import json
import os
import subprocess
import sys
import threading
import time
from socket import AF_UNIX, SHUT_WR, socket

# 参与自动堆叠的 app_id（大小写不敏感比较）：Wayland 下 alacritty 上报
# "Alacritty"，XWayland/--class 也可能给出别的写法。想扩展到其它终端时在此
# 追加，例如 "kitty"、"ghostty"、"com.mitchellh.ghostty"。
STACK_APP_IDS = {"alacritty"}

# 新窗口事件后等待多久再读快照（事件可能早于布局就绪）
SETTLE_DELAY = 0.1

# 等待新窗口出现在窗口列表里（并拿到布局位置）的最长时间
READY_TIMEOUT = 2.0

# 暂停开关：文件存在时不处理新窗口
OFF_FILE = "/tmp/niri-auto-stack.off"

LOCK_FILE = "/tmp/niri-auto-stack.lock"


def log(message: str) -> None:
    print(f"{time.strftime('%H:%M:%S')} {message}", flush=True)


def resolve_niri_socket() -> str | None:
    """定位 niri IPC socket。

    优先使用 NIRI_SOCKET；systemd 用户服务可能在会话环境导入之前就已启动，
    而进程环境不会随 manager 环境更新，此时回退到 XDG_RUNTIME_DIR 下最新
    创建的 niri.*.sock（同 dynamic-float.py）。
    """
    if path := os.environ.get("NIRI_SOCKET"):
        return path
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    candidates = glob.glob(os.path.join(runtime_dir, "niri.*.sock"))
    if not candidates:
        return None
    return max(candidates, key=os.path.getmtime)


def niri_json(*args):
    """执行 niri msg --json <args> 并解析输出。"""
    result = subprocess.run(
        ["niri", "msg", "--json", *args], capture_output=True, text=True
    )
    return json.loads(result.stdout)


def niri_action(*args) -> bool:
    result = subprocess.run(
        ["niri", "msg", "action", *args], capture_output=True, text=True
    )
    if result.returncode != 0:
        log(f"action {' '.join(args)} failed: {result.stderr.strip()}")
        return False
    return True


def column_of(window):
    """窗口所在列号（1 起）；浮动窗口 / 还没布局时返回 None。"""
    pos = (window.get("layout") or {}).get("pos_in_scrolling_layout")
    return pos[0] if pos else None


def is_stack_app(window) -> bool:
    return (window.get("app_id") or "").casefold() in STACK_APP_IDS


def pick_neighbour(windows, window, direction: int):
    """在 offset 方向（-1 左 / +1 右）的相邻列里找同类终端窗口。"""
    column = column_of(window)
    if column is None:
        return None
    target = column + direction
    if target < 1:
        return None
    for other in windows:
        if other["id"] == window["id"]:
            continue
        if other.get("workspace_id") != window.get("workspace_id"):
            continue
        if column_of(other) == target and is_stack_app(other):
            return other
    return None


def column_size(windows, window) -> int:
    """新窗口所在列里的窗口数。"""
    column = column_of(window)
    if column is None:
        return 0
    return sum(
        1
        for other in windows
        if other.get("workspace_id") == window.get("workspace_id")
        and column_of(other) == column
    )


def stack_window(window_id: int) -> None:
    """把新窗口并入相邻的同类终端列（若存在），否则什么都不做。"""
    deadline = time.monotonic() + READY_TIMEOUT
    while True:
        windows = niri_json("windows")
        window = next((w for w in windows if w["id"] == window_id), None)
        if window is None:
            return  # 窗口已经关掉了
        if not window.get("is_floating") and column_of(window) is not None:
            break
        if time.monotonic() >= deadline:
            return
        time.sleep(0.05)

    if os.path.exists(OFF_FILE):
        return
    if column_size(windows, window) != 1:
        return  # 已经不在自己的单窗口列里，别和手动操作打架

    for direction, action in ((-1, "consume-or-expel-window-left"), (1, "consume-or-expel-window-right")):
        neighbour = pick_neighbour(windows, window, direction)
        if neighbour is None:
            continue
        log(
            f"stack window {window_id} ({window.get('app_id')!r}) "
            f"into the column of window {neighbour['id']}"
        )
        niri_action(action, "--id", str(window_id))
        return


def handle_new_window(window_id: int) -> None:
    time.sleep(SETTLE_DELAY)
    try:
        stack_window(window_id)
    except Exception as error:
        log(f"stack window {window_id} error: {error}")


def main() -> None:
    while True:
        try:
            seen: set[int] = set()
            snapshot_received = False
            socket_path = resolve_niri_socket()
            if socket_path is None:
                raise RuntimeError(
                    "NIRI_SOCKET not set and no niri.*.sock found in XDG_RUNTIME_DIR"
                )
            niri_socket = socket(AF_UNIX)
            niri_socket.connect(socket_path)
            file = niri_socket.makefile("rw")
            _ = file.write('"EventStream"')
            file.flush()
            niri_socket.shutdown(SHUT_WR)
            for line in file:
                event = json.loads(line)
                if changed := event.get("WindowsChanged"):
                    # 配置重载等时机发来的全量窗口快照
                    seen = {win["id"] for win in changed["windows"]}
                    snapshot_received = True
                    log(
                        f"watching {len(seen)} existing windows; "
                        "stacking only newly opened ones"
                    )
                elif changed := event.get("WindowOpenedOrChanged"):
                    win = changed["window"]
                    if not snapshot_received or win["id"] in seen:
                        continue
                    if not win.get("app_id"):
                        continue  # app_id 未上报，等后续事件再判断
                    seen.add(win["id"])
                    if not is_stack_app(win):
                        continue
                    log(f"new window {win['id']} app_id={win.get('app_id')!r}")
                    threading.Thread(
                        target=handle_new_window, args=(win["id"],), daemon=True
                    ).start()
                elif changed := event.get("WindowClosed"):
                    seen.discard(changed["id"])
                elif changed := event.get("WindowsDeleted"):
                    # 兼容旧版事件名
                    seen.discard(changed["id"])
        except Exception as error:
            log(f"event stream error: {error}, retrying in 5s")
            time.sleep(5)


if __name__ == "__main__":
    # 单实例锁：避免重复运行多个监听
    lock = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("another instance is running, exit", flush=True)
        sys.exit(0)

    main()
