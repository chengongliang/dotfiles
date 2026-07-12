#!/usr/bin/env bash
# ~/dotfiles/setup.sh - Bootstrap a new machine with dotfiles
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Dotfiles Bootstrap ===${NC}"

# --- 1. Install paru (AUR helper) if missing ---
if ! command -v paru &>/dev/null; then
    echo -e "${CYAN}Installing paru (AUR helper)...${NC}"
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    cd /tmp/paru && makepkg -si --noconfirm && cd -
    rm -rf /tmp/paru
fi

# --- 2. Install all packages ---
# NOTE: 包名已逐一核对存在性。底部工具是 bottom(非 bottom-git,AUR 上的 -git 版已废弃)。
PACKAGES=(
    # Core
    stow git

    # Shell + tools
    fish eza fzf zoxide

    # Editor
    neovim

    # Terminals (three of them, keep all)
    kitty kitty-shell-integration kitty-terminfo
    alacritty
    ghostty ghostty-shell-integration ghostty-terminfo

    # Tmux
    tmux

    # Herdr (agent multiplexer, AUR)
    herdr

    # System / tools
    btop
    fastfetch
    lazygit
    micro
    bottom
    yazi
    niri
    opencode
    zed
)

echo -e "${CYAN}Installing packages via paru...${NC}"
sudo paru -S --noconfirm --needed "${PACKAGES[@]}"

# --- 2b. g（Go 版本管理器） ---
# 非官方包，通过官方安装脚本安装到 ~/.g。fish 配置中 source ~/.g/env.fish。
if ! command -v g &>/dev/null && [ ! -d "$HOME/.g" ]; then
    echo -e "${CYAN}Installing g (Go version manager)...${NC}"
    curl -fsSL https://raw.githubusercontent.com/stefanmaric/g/main/install.sh | bash -s -- -y 2>/dev/null || true
fi

# --- 2c. LM Studio CLI (lms) ---
# 非官方包，通过官方脚本安装到 ~/.lmstudio/bin。fish 配置中已加入该 PATH。
if ! command -v lms &>/dev/null && [ ! -d "$HOME/.lmstudio/bin" ]; then
    echo -e "${CYAN}Installing LM Studio CLI (lms)...${NC}"
    curl -fsSL https://raw.githubusercontent.com/lmstudio-ai/lms/main/scripts/install.sh | bash 2>/dev/null || true
fi

# --- 3. Install Fish plugins ---
if command -v fish &>/dev/null; then
    echo -e "${CYAN}Installing Fish plugins...${NC}"
    fish -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher" 2>/dev/null || true
    fish -c "fisher install tuvistavie/fish-autopair" 2>/dev/null || true
fi

# --- 4. Install fnm (Node version manager) ---
if ! command -v fnm &>/dev/null; then
    echo -e "${CYAN}Installing fnm...${NC}"
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell 2>/dev/null || true
fi

# --- 5. Clone dotfiles ---
DOTFILES_DIR="${1:-$HOME/dotfiles}"
if [ ! -d "$DOTFILES_DIR/.git" ]; then
    if [ -d "$DOTFILES_DIR" ]; then
        echo -e "${RED}$DOTFILES_DIR exists but is not a git repo.${NC}"
        exit 1
    fi
    echo -e "${CYAN}Cloning dotfiles...${NC}"
    git clone git@github.com:chengongliang/dotfiles.git "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"

# --- 6. Submodules ---
echo -e "${CYAN}Initializing git submodules...${NC}"
git submodule update --init --recursive

# --- 7. Deploy symlinks ---
# 若目标位置已存在非符号链接文件/目录（旧配置），stow 会冲突。
# 备份后替换，避免阻塞部署。
backup_existing() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        local bk="${target}.prestow.$(date +%Y%m%d%H%M%S)"
        echo -e "${CYAN}Backing up existing $target → $bk${NC}"
        mv "$target" "$bk"
    fi
}

echo -e "${CYAN}Deploying home dotfiles (.gitconfig, .npmrc, .tmux.conf)...${NC}"
for f in .gitconfig .npmrc .tmux; do
    backup_existing "$HOME/$f"
done
mkdir -p "$HOME/.tmux/plugins"
stow --no-folding -t "$HOME" home

# Recreate ~/.tmux.conf -> .tmux/.tmux.conf symlink
backup_existing "$HOME/.tmux.conf"
ln -sf .tmux/.tmux.conf "$HOME/.tmux.conf"

echo -e "${CYAN}Deploying XDG config (~/.config/)...${NC}"
# 对 config/ 下的每个 app 目录，备份本地已存在的同名目录/文件
for app in $(find config -maxdepth 1 -mindepth 1 -type d -printf '%f\n'); do
    backup_existing "$HOME/.config/$app"
done
stow -t "$HOME/.config" config

# --- 8. Install Tmux plugins via TPM ---
if command -v tmux &>/dev/null && [ -f "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
    echo -e "${CYAN}Installing Tmux plugins via TPM...${NC}"
    # TPM needs a running tmux server to install; start a headless one
    tmux new-session -d -s __install 2>/dev/null || true
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" 2>/dev/null || true
    tmux kill-session -t __install 2>/dev/null || true
fi

# --- 9. Set default shell to fish ---
if [[ "$SHELL" != *fish ]]; then
    echo -e "${CYAN}Setting default shell to fish...${NC}"
    chsh -s /usr/bin/fish 2>/dev/null || echo -e "${RED}chsh failed — run manually: chsh -s /usr/bin/fish${NC}"
fi

# --- Done ---
echo ""
echo -e "${GREEN}=== All done! Symlinks are in place. ===${NC}"
echo ""
echo -e "${CYAN}Post-install steps:${NC}"
echo "  1. Neovim plugins:   nvim --headless '+Lazy! sync' +qa"
echo "  2. SSH keys:         ssh-keygen or copy manually"
echo "  3. GPG keys:         gpg --import or gpg --gen-key"
echo "  4. Kube config:      place ~/.kube/config"
echo ""
echo -e "${CYAN}To undo symlinks:${NC}"
echo "  cd ~/dotfiles && stow --delete -t ~ home && stow --delete -t ~/.config config"
