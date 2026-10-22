#!/usr/bin/env python3
"""恢复 Noctalia 5.x 的工作区应用图标；不纳入 Stow 部署。

用法：python3 patches/restore-noctalia-workspace-icons.py [配置文件]
修改前校验并备份，之后运行 noctalia msg config-reload 生效。
"""

import json
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
from datetime import datetime
from pathlib import Path


def update_section(text, section, values):
    # 保留其他字段及注释，仅更新指定表内的选项。
    pattern = rf"(?m)^\[{re.escape(section)}\][ \t]*\n.*?(?=^\[|\Z)"
    match = re.search(pattern, text, flags=re.S)
    block = match.group() if match else f"[{section}]\n"
    for key, value in values.items():
        line = f"{key} = {value}\n"
        key_pattern = rf"(?m)^{re.escape(key)}[ \t]*=.*(?:\n|$)"
        if re.search(key_pattern, block):
            block = re.sub(key_pattern, lambda _: line, block)
        else:
            block = block.rstrip() + "\n" + line
    block = block.rstrip() + "\n"
    if match:
        suffix = text[match.end():]
        return text[:match.start()] + block + ("\n" if suffix else "") + suffix
    return text.rstrip() + "\n\n" + block


def main():
    config = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / ".config/noctalia/noctalia-config.toml"
    original = config.read_text()
    data = tomllib.loads(original)
    center = data["bar"]["default"]["center"]
    if not any(widget in center for widget in ("workspaces", "taskbar")):
        raise SystemExit("中央栏未配置 workspaces 或 taskbar，请先确认工作区组件位置。")
    center = ["taskbar" if widget == "workspaces" else widget for widget in center]
    updated = update_section(original, "bar.default", {"center": json.dumps(center)})
    updated = update_section(updated, "widget.taskbar", {
        "group_by_workspace": "true",
        "workspace_group_content": '"icons"',
        "show_workspace_label": "true",
        "hide_empty_workspaces": "false",
        "only_active_workspace": "false",
        "show_all_outputs": "false",
    })
    if updated == original:
        print(f"配置已恢复，无需修改：{config}")
        return
    with tempfile.TemporaryDirectory(prefix="noctalia-workspace-icons-") as directory:
        candidate = Path(directory) / "config.toml"
        candidate.write_text(updated)
        subprocess.run(["noctalia", "config", "validate", str(candidate)], check=True)
    backup = config.with_name(config.name + datetime.now().strftime(".bak-%Y%m%d-%H%M%S-%f"))
    shutil.copy2(config, backup)
    config.write_text(updated)
    print(f"已恢复工作区应用图标：{config}\n原配置备份：{backup}")


if __name__ == "__main__":
    main()
