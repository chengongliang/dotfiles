#!/usr/bin/python3
"""niri 动态浮动脚本（dynamic open-float）。

Firefox/Zen 系应用先以占位标题打开窗口、之后才更新标题，导致 niri
window-rule 的 open-floating 按 title 匹配不到（见 niri FAQ）。本脚本
监听 niri IPC 事件流，只在新窗口的标题/应用 ID 初始化阶段匹配浮动
规则；最多等待 10 秒，首个非占位标题匹配完成后不再处理该窗口。
收到完整窗口快照后，只有事件流中首次出现的新窗口 ID 才参与匹配；
连接时已有的窗口、断线重连的窗口均不处理，普通标签页不会被视为新窗口。
改写自官方方案：
https://github.com/niri-wm/niri/discussions/1599

由 autostart.kdl 通过 spawn-sh-at-startup 启动。规则列表 RULES（见下方）
的语义等同 niri 配置里的 window-rule {}（match 任一命中且不命中 exclude），
另支持 size=（浮动后固定尺寸）与 center=True（浮动后居中到所在显示器）。
"""

import fcntl
import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from socket import AF_UNIX, SHUT_WR, socket


@dataclass(kw_only=True)
class Match:
    title: str | None = None
    app_id: str | None = None

    def matches(self, window) -> bool:
        if self.title is None and self.app_id is None:
            return False
        matched = True
        if self.title is not None:
            matched &= re.search(self.title, window.get("title") or "") is not None
        if self.app_id is not None:
            matched &= re.search(self.app_id, window.get("app_id") or "") is not None
        return matched


@dataclass
class Rule:
    match: list[Match] = field(default_factory=list)
    exclude: list[Match] = field(default_factory=list)
    # 浮动后把窗口调整到固定尺寸（逻辑像素），如 size=(950, 970)
    size: tuple[int, int] | None = None
    # 浮动后在窗口所在显示器内居中
    center: bool = False
    # 匹配后直接关闭窗口（用于钉钉透明覆盖层等无功能、
    # 且经 xwayland-satellite 丢失 input region 而遮挡点击的弹层）
    close: bool = False

    def matches(self, window) -> bool:
        if len(self.match) > 0 and not any(m.matches(window) for m in self.match):
            return False
        if any(m.matches(window) for m in self.exclude):
            return False
        return True


# 在这里添加规则，一个 Rule() = 一个 window-rule {}
RULES = [
    # Zen OAuth 授权弹窗，如 "Authorize - LINUX DO Connect — Zen Browser"
    Rule(
        [Match(title=r"^Authorize\b", app_id=r"^zen$")],
        size=(950, 970),
        center=True,
    ),
    # Zen Bitwarden 密码管理器弹窗（同样存在标题延迟设置的问题）
    Rule([Match(title=r"[Bb]itwarden", app_id=r"^zen$")]),
    # 钉钉透明覆盖层 / toast 载体（title 与 app-id 同名）：经 xwayland-satellite
    # 丢失 X11 input region，整层悬浮挡住主窗口点击，只能等它自动消失。
    # 直接关闭（钉钉自身几秒后也会销毁它，提前关闭无副作用）。
    Rule(
        [Match(title=r"^com\.alibabainc\.dingtalk$", app_id=r"^com\.alibabainc\.dingtalk$")],
        close=True,
    ),
]

INITIALIZATION_TIMEOUT = 10.0
PLACEHOLDER_TITLES = {
    "",
    "zen",
    "zen browser",
    "about:blank",
    "about:blank — zen browser",
}


def niri_json(*args):
    """执行 niri msg --json <args> 并解析输出。"""
    r = subprocess.run(
        ["niri", "msg", "--json", *args], capture_output=True, text=True
    )
    return json.loads(r.stdout)


def niri_action(*args):
    subprocess.run(
        ["niri", "msg", "action", *args],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def find_window(window_id: int):
    return next(
        (window for window in niri_json("windows") if window["id"] == window_id),
        None,
    )


def float_window(window_id: int) -> None:
    # move-window-to-floating 对已浮动窗口是 no-op（非 toggle），可安全重复调用
    niri_action("move-window-to-floating", "--id", str(window_id))


def resize_window(window_id: int, size: tuple[int, int]) -> tuple[int, int] | None:
    window = find_window(window_id)
    if window is None:
        return None
    workspace = next(
        (
            workspace
            for workspace in niri_json("workspaces")
            if workspace["id"] == window.get("workspace_id")
        ),
        None,
    )
    if workspace is None:
        return None
    output = niri_json("outputs").get(workspace.get("output"))
    logical = output.get("logical") if output else None
    if logical is None:
        return None

    width = max(1, min(size[0], int(logical["width"]) - 40))
    height = max(1, min(size[1], int(logical["height"]) - 40))
    niri_action("set-window-width", "--id", str(window_id), str(width))
    niri_action("set-window-height", "--id", str(window_id), str(height))
    return width, height


def center_window(window_id: int, size: tuple[int, int] | None) -> None:
    try:
        deadline = time.monotonic() + 1.0
        window = find_window(window_id)
        while window is not None:
            size_ready = size is None or tuple(window["layout"]["window_size"]) == size
            if window.get("is_floating") and size_ready:
                break
            if time.monotonic() >= deadline:
                break
            time.sleep(0.05)
            window = find_window(window_id)
        if window is not None and window.get("is_floating"):
            niri_action("center-window", "--id", str(window_id))
    except Exception as error:
        print(f"center window {window_id} error: {error}", flush=True)


def apply_rule(window_id: int, rule: Rule) -> None:
    if rule.close:
        # 略作延迟，让提示文字短暂可见后再关闭（不阻塞主循环太久）
        time.sleep(0.5)
        niri_action("close-window", "--id", str(window_id))
        return
    float_window(window_id)
    size = resize_window(window_id, rule.size) if rule.size else None
    if rule.center:
        center_window(window_id, size)


def update_matched(window, windows, *, allow_new: bool = False) -> None:
    now = time.monotonic()
    previous_window = windows.get(window["id"])
    deadline = previous_window.get("match_deadline") if previous_window else None
    if previous_window is None and allow_new:
        deadline = now + INITIALIZATION_TIMEOUT
    window["match_deadline"] = deadline
    if deadline is None or now >= deadline:
        window["match_deadline"] = None
        return
    if not window.get("app_id"):
        return

    matched_rule = next((rule for rule in RULES if rule.matches(window)), None)
    if matched_rule is None:
        title = (window.get("title") or "").strip().casefold()
        if title not in PLACEHOLDER_TITLES:
            window["match_deadline"] = None
        return

    window["match_deadline"] = None
    print(
        f"floating window {window['id']}: "
        f"title={window.get('title')!r}, app_id={window.get('app_id')!r}",
        flush=True,
    )
    apply_rule(window["id"], matched_rule)


def main() -> None:
    while True:
        try:
            windows: dict = {}
            snapshot_received = False
            niri_socket = socket(AF_UNIX)
            niri_socket.connect(os.environ["NIRI_SOCKET"])
            file = niri_socket.makefile("rw")
            _ = file.write('"EventStream"')
            file.flush()
            niri_socket.shutdown(SHUT_WR)
            for line in file:
                event = json.loads(line)
                if changed := event.get("WindowsChanged"):
                    # 配置重载等时机发来的全量窗口快照
                    windows = {win["id"]: win for win in changed["windows"]}
                    snapshot_received = True
                    print(
                        f"watching {len(windows)} existing windows; "
                        "floating only newly opened windows",
                        flush=True,
                    )
                elif changed := event.get("WindowOpenedOrChanged"):
                    win = changed["window"]
                    update_matched(
                        win,
                        windows,
                        allow_new=snapshot_received and win["id"] not in windows,
                    )
                    windows[win["id"]] = win
                elif changed := event.get("WindowClosed"):
                    windows.pop(changed["id"], None)
                elif changed := event.get("WindowsDeleted"):
                    # 兼容旧版事件名
                    windows.pop(changed["id"], None)
        except Exception as e:
            print(f"event stream error: {e}, retrying in 5s", flush=True)
            time.sleep(5)


if __name__ == "__main__":
    # 单实例锁：避免重复运行多个监听
    lock = open("/tmp/niri-dynamic-float.lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("another instance is running, exit", flush=True)
        sys.exit(0)

    main()
