# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/) and Git.

[简体中文](README.zh-CN.md)

## Overview

This repository stores my Linux desktop and development environment configuration.
It is mainly designed for Arch-based systems, uses `paru` for package
installation, and deploys files as symlinks through GNU Stow.

The bootstrap script is intentionally opinionated: it installs packages, sets up
Fish, initializes the Tmux plugin submodule, deploys symlinks, and leaves private
machine-specific files out of the repository.

## Structure

```text
~/dotfiles/
├── home/          # deployed to $HOME
│   ├── .gitconfig
│   ├── .npmrc
│   └── .tmux/
├── config/        # deployed to $HOME/.config
│   ├── fish/
│   ├── nvim/
│   ├── kitty/
│   ├── alacritty/
│   └── ...
├── setup.sh       # bootstrap script for new machines
└── README.md
```

## Quick Start

On a new Arch-based machine:

```bash
curl -fsSL https://raw.githubusercontent.com/chengongliang/dotfiles/main/setup.sh | bash
```

By default, the script clones this repository into `~/dotfiles`. To use another
directory:

```bash
curl -fsSL https://raw.githubusercontent.com/chengongliang/dotfiles/main/setup.sh | bash -s -- ~/src/dotfiles
```

What the script does:

- Installs `paru` if it is missing.
- Installs packages with `paru`.
- Installs `g`, `lms`, Fish plugins, and `fnm` when missing.
- Clones the repository and initializes submodules.
- Backs up existing non-symlink targets with a `.prestow.<timestamp>` suffix.
- Deploys `home/` to `$HOME` and `config/` to `$HOME/.config`.
- Installs Tmux plugins through TPM.
- Attempts to set Fish as the default shell.

## Manual Install

Install the required tools first:

```bash
sudo pacman -S --needed git stow
```

Clone and initialize submodules:

```bash
git clone git@github.com:chengongliang/dotfiles.git ~/dotfiles
cd ~/dotfiles
git submodule update --init --recursive
```

Preview the symlink plan:

```bash
stow --simulate -t ~ home
stow --simulate -t ~/.config config
```

Deploy:

```bash
cd ~/dotfiles
stow -t ~ home
stow -t ~/.config config
ln -sf .tmux/.tmux.conf ~/.tmux.conf
```

## What's Included

| Area | Config |
| --- | --- |
| Shell | Fish, Fisher plugins, `fnm`, `g`, `zoxide`, `fzf` |
| Editors | Neovim, micro, Zed |
| Terminals | Kitty, Alacritty, Ghostty |
| Tmux | TPM, Dracula theme, resurrect/continuum |
| Window manager | niri |
| Lock screen | hyprlock, styled after the Windows 11 lock screen |
| CLI tools | btop, bottom, fastfetch, lazygit, yazi, opencode, paru |
| Git | Global Git config and XDG global ignore file |

### Lock screen

`config/hypr/` holds a hyprlock setup that mimics the Windows 11 idle lock
screen: sharp wallpaper, a large clock near the top, a bold date underneath,
and no avatar or password box until you start typing.

The wallpaper follows whatever the noctalia shell is currently using.
`scripts/lock.sh` reads noctalia's wallpaper state, writes a throwaway runtime
config into `$XDG_RUNTIME_DIR`, and hands that to `hyprlock -c`, so
`hyprlock.conf` itself stays generic and machine-independent. If the state file
cannot be read it falls back to the wallpaper bundled with noctalia.

Both lock entry points call that script: the niri keybind `Mod+Alt+L`, and
noctalia's idle `lockCommand`. The keybind ships with this repo; noctalia's own
settings are not tracked, so on a new machine point its `lockCommand` at
`~/.config/hypr/scripts/lock.sh` by hand. Fonts come from `ttf-wps-fonts`
(Segoe UI family) and `noto-fonts-cjk` (CJK date line).

Note: `font_size` in `hyprlock.conf` is in **points**, not pixels — hyprgraphics
calls `pango_font_description_set_size()` at 96 DPI, so rendered px = pt x 4/3.

## Verification

Useful checks after changes:

```bash
bash -n setup.sh
stow --simulate -t ~ home
stow --simulate -t ~/.config config
```

For lock screen script changes:

```bash
bash -n config/hypr/scripts/lock.sh
```

For Fish config changes:

```bash
fish -n config/fish/config.fish
```

For Neovim changes:

```bash
nvim --headless '+Lazy! sync' +qa
```

## Updating

```bash
cd ~/dotfiles
git pull --recurse-submodules
git submodule update --init --recursive
stow -t ~ home
stow -t ~/.config config
```

## Excluded (manual setup)

These files are intentionally not tracked:

- `~/.ssh/`: SSH keys and host-specific SSH config.
- `~/.gnupg/`: GPG keys and trust database.
- `~/.kube/`: Kubernetes credentials and cluster config.
- Tokens, private certificates, cloud credentials, and other secrets.

## Reverting

```bash
cd ~/dotfiles && stow --delete -t ~ home && stow --delete -t ~/.config config
rm -f ~/.tmux.conf
```

Review any `.prestow.<timestamp>` backups before deleting them.
