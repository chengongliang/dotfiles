# Dotfiles

使用 [GNU Stow](https://www.gnu.org/software/stow/) 和 Git 管理的个人 dotfiles。

[English](README.md)

## 概览

这个仓库存放我的 Linux 桌面和开发环境配置。主要目标环境是 Arch 系 Linux，
包安装默认使用 `paru`，配置文件通过 GNU Stow 以符号链接方式部署。

`setup.sh` 是一个偏个人习惯的新机器 bootstrap 脚本：它会安装软件包、配置
Fish、初始化 Tmux 插件子模块、部署符号链接，并且不会管理机器私有文件。

## 目录结构

```text
~/dotfiles/
├── home/          # 部署到 $HOME
│   ├── .gitconfig
│   ├── .npmrc
│   └── .tmux/
├── config/        # 部署到 $HOME/.config
│   ├── fish/
│   ├── nvim/
│   ├── kitty/
│   ├── alacritty/
│   └── ...
├── setup.sh       # 新机器 bootstrap 脚本
└── README.md
```

## 快速开始

在新的 Arch 系机器上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/chengongliang/dotfiles/main/setup.sh | bash
```

脚本默认把仓库克隆到 `~/dotfiles`。如果想指定其他目录：

```bash
curl -fsSL https://raw.githubusercontent.com/chengongliang/dotfiles/main/setup.sh | bash -s -- ~/src/dotfiles
```

脚本会执行这些操作：

- 缺少 `paru` 时自动安装。
- 使用 `paru` 安装软件包。
- 缺少 `g`、`lms`、Fish 插件、`fnm` 时自动安装。
- 克隆仓库并初始化子模块。
- 对已有的非符号链接目标创建 `.prestow.<timestamp>` 备份。
- 将 `home/` 部署到 `$HOME`，将 `config/` 部署到 `$HOME/.config`。
- 通过 TPM 安装 Tmux 插件。
- 尝试把默认 shell 设置为 Fish。

## 手动安装

先安装必要工具：

```bash
sudo pacman -S --needed git stow
```

克隆仓库并初始化子模块：

```bash
git clone git@github.com:chengongliang/dotfiles.git ~/dotfiles
cd ~/dotfiles
git submodule update --init --recursive
```

预览符号链接计划：

```bash
stow --simulate -t ~ home
stow --simulate -t ~/.config config
```

部署配置：

```bash
cd ~/dotfiles
stow -t ~ home
stow -t ~/.config config
ln -sf .tmux/.tmux.conf ~/.tmux.conf
```

## 包含内容

| 类型 | 配置 |
| --- | --- |
| Shell | Fish、Fisher 插件、`fnm`、`g`、`zoxide`、`fzf` |
| 编辑器 | Neovim、micro、Zed |
| 终端 | Kitty、Alacritty、Ghostty |
| Tmux | TPM、Dracula theme、resurrect/continuum |
| 窗口管理器 | niri |
| CLI 工具 | btop、bottom、fastfetch、lazygit、yazi、opencode、paru |
| Git | 全局 Git 配置和 XDG 全局 ignore 文件 |

## 验证

修改后常用检查：

```bash
bash -n setup.sh
stow --simulate -t ~ home
stow --simulate -t ~/.config config
```

修改 Fish 配置后：

```bash
fish -n config/fish/config.fish
```

修改 Neovim 配置后：

```bash
nvim --headless '+Lazy! sync' +qa
```

## 更新

```bash
cd ~/dotfiles
git pull --recurse-submodules
git submodule update --init --recursive
stow -t ~ home
stow -t ~/.config config
```

## 不纳入仓库的内容

这些文件需要手动迁移或在新机器上重新生成：

- `~/.ssh/`：SSH key 和主机相关 SSH 配置。
- `~/.gnupg/`：GPG key 和 trust database。
- `~/.kube/`：Kubernetes 凭据和集群配置。
- token、私有证书、云服务凭据等其他敏感信息。

## 撤销部署

```bash
cd ~/dotfiles && stow --delete -t ~ home && stow --delete -t ~/.config config
rm -f ~/.tmux.conf
```

删除 `.prestow.<timestamp>` 备份前建议先确认内容。
