# AGENTS.md

## 项目概览

这是个人 dotfiles 仓库，使用 Git 和 GNU Stow 管理配置文件。

- `home/`：部署到 `$HOME`，包含 `.gitconfig`、`.npmrc`、`.tmux/` 等。
- `config/`：部署到 `$HOME/.config`，包含 fish、Neovim、kitty、alacritty、ghostty、niri、fastfetch、lazygit 等应用配置。其中 `config/hypr/`（Win11 风格 hyprlock 锁屏）是**可选项**，只在需要它的机器上启用（`setup.sh` 会询问，或用 `WITH_HYPR=1` 强制启用）。
- `pi/`：部署到 `$HOME/.pi`，包含 pi coding agent 的配置（`settings.json`、`mcp.json`、`open-tui.json`、`AGENTS.md`、`extensions/*.ts`、`npm/package.json`）。运行时数据与主机专属文件（`models.json`、`auth.json`、`trust.json`、`sessions/`、`skills/` 等）通过 `pi/.gitignore` 排除。
- `setup.sh`：新机器 bootstrap 脚本，主要面向 Arch 系发行版，并依赖 `paru`。
- `home/.tmux/plugins/tpm`：Tmux Plugin Manager 子模块。

## 常用命令

手动部署：

```bash
stow -t ~ home
stow -t ~/.config config
stow --no-folding -t ~/.pi pi
```

可选的 hyprlock 锁屏（`config/hypr/`）默认随 `stow -t ~/.config config` 一起部署；
不需要它的机器可以单独撤销：

```bash
unlink ~/.config/hypr   # 或用 setup.sh 部署时 WITH_HYPR=0，会自动排除
```

撤销部署：

```bash
stow --delete -t ~ home
stow --delete -t ~/.config config
stow --delete -t ~/.pi pi
```

初始化子模块：

```bash
git submodule update --init --recursive
```

检查 shell 脚本语法：

```bash
bash -n setup.sh
```

Neovim 插件同步：

```bash
nvim --headless '+Lazy! sync' +qa
```

## 修改准则

- 优先保持现有目录结构：新增 XDG 配置放在 `config/<app>/`，新增 home 级 dotfile 放在 `home/`，pi 相关配置放在 `pi/`。
- 不要把私密内容提交到仓库，包括 SSH key、GPG key、Kubernetes 配置、token、主机专属凭据等。`~/.pi/agent/models.json`、`auth.json`、`trust.json` 等含私有/凭据信息或主机专属路径的文件不纳入仓库。
- 修改 `setup.sh` 时保持幂等性：重复执行不应破坏已有配置；新增软件包前确认包名适用于 Arch/paru。
- 修改 Stow 管理的文件时注意目标路径冲突，避免引入会覆盖用户本地私有文件的逻辑。`pi/` 部署必须使用 `--no-folding`，因为 `~/.pi/agent/` 含大量运行时文件，折叠链接整个目录会覆盖它们。
- 这个仓库混合使用英文和中文注释；新增仓库级说明优先使用中文，配置文件内部遵循原文件风格。
- 保持变更范围小，不做无关格式化或大规模重排。

## 验证建议

- 修改 `setup.sh` 后至少运行 `bash -n setup.sh`。
- 修改 Stow 结构后，可用 `stow --simulate -t ~ home`、`stow --simulate -t ~/.config config` 或 `stow --simulate --no-folding -t ~/.pi pi` 检查链接计划。
- 修改 Neovim Lua 配置后，优先运行 `nvim --headless '+Lazy! sync' +qa` 或至少检查相关 Lua 文件语法。
- 修改 Fish 配置后，可用 `fish -n <file>` 检查语法。

## 环境假设

- 主要目标环境是 Arch 系 Linux。
- 默认 shell 期望为 fish。
- 包管理器优先使用 `paru`。
- 配置通过符号链接部署，不建议直接编辑已部署到 `$HOME` 或 `$HOME/.config` 的目标文件。`pi/` 包含用户自定义扩展（`extensions/*.ts`）与 npm 依赖声明（`npm/package.json`），扩展的 npm 源码产物不纳入仓库。
