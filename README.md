# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/) + Git.

## Structure

```
~/dotfiles/
├── home/          → stow -t ~        (.gitconfig, .npmrc, .tmux.conf)
├── config/        → stow -t ~/.config (fish, nvim, kitty, alacritty, ...)
├── setup.sh       # bootstrap a new machine
└── README.md
```

## Quick Start

**On a new machine (requires an Arch-based system with paru):**

```bash
curl -fsSL https://raw.githubusercontent.com/chengongliang/dotfiles/main/setup.sh | bash
```

The script installs all packages (via paru), sets up fish as default shell, clones the repo, and deploys symlinks.

**Or manually:**

```bash
cd ~/dotfiles
stow -t ~ home              # deploy home dotfiles
stow -t ~/.config config    # deploy XDG config
```

## What's Included

| Area | Config |
|---|---|
| **Shell** | Fish (config.fish, functions) |
| **Terminals** | Kitty, Alacritty, Ghostty |
| **Editor** | Neovim (lazy.nvim), micro (with vendored Catppuccin Macchiato theme) |
| **Tmux** | TPM, Dracula theme, resurrect/continuum |
| **Tools** | btop, fastfetch, lazygit, micro, niri, opencode, paru, bottom, gitignore, zed |

## Excluded (manual setup)

- `~/.ssh/` — SSH keys (copy or generate on new machine)
- `~/.gnupg/` — GPG keys (import on new machine)
- `~/.kube/` — Kubernetes config (place on new machine)

## Reverting

```bash
cd ~/dotfiles && stow --delete -t ~ home && stow --delete -t ~/.config config
```
