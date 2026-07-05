# Cachyos 默认 fish 配置（提供 PATH、补全等基础环境）
source /usr/share/cachyos-fish-config/cachyos-config.fish

# g（Go 版本管理器）环境
if test -s "$HOME/.g/env.fish"; and source "$HOME/.g/env.fish"; end

# 覆盖 greeting：仅在终端足够大时显示 fastfetch
function fish_greeting
    if test $COLUMNS -ge 73; and test $LINES -ge 24
        fastfetch
    end
end

# ─── 代理配置 ───
function px --description "开启系统代理"
    set -gx http_proxy "http://127.0.0.1:3067"
    set -gx https_proxy "http://127.0.0.1:3067"
    set -gx no_proxy "127.0.0.1"
    set -gx all_proxy "http://127.0.0.1:3067"
    echo "✓ 代理已开启 (http://127.0.0.1:3067)"
end

function poff --description "关闭系统代理"
    set -e http_proxy
    set -e https_proxy
    set -e all_proxy
    set -e no_proxy
    echo "✓ 代理已关闭"
end

# ─── Git fzf 辅助函数 ───
function fco -d "Use `fzf` to choose which branch to check out" --argument-names branch
  set -q branch[1]; or set branch ''
  git for-each-ref --format='%(refname:short)' refs/heads | fzf --height 10% --layout=reverse --border --query=$branch --select-1 | xargs git checkout
end

function fcoc -d "Fuzzy-find and checkout a commit"
  git log --pretty=oneline --abbrev-commit --reverse | fzf --tac +s -e | awk '{print $1;}' | read -l result; and git checkout "$result"
end

function snag -d "Pick desired files from a chosen branch"
  set branch (git for-each-ref --format='%(refname:short)' refs/heads | fzf --height 20% --layout=reverse --border)
  if test -n "$branch"
    set files (git diff --name-only $branch | fzf --height 20% --layout=reverse --border --multi)
  end
  if test -n "$files"
    git checkout $branch $files
  end
end

function fzum -d "View all unmerged commits across all local branches"
  set viewUnmergedCommits "echo {} | head -1 | xargs -I BRANCH sh -c 'git log master..BRANCH --no-merges --color --format=\"%C(auto)%h - %C(green)%ad%Creset - %s\" --date=format:\'%b %d %Y\''"
  git branch --no-merged master --format "%(refname:short)" | fzf --no-sort --reverse --tiebreak=index --no-multi \
    --ansi --preview="$viewUnmergedCommits"
end

# ─── alias: eza ───
alias ls 'eza --icons'
alias ll 'eza -l --icons'
alias lt 'eza --tree --icons'

# Docker
set -gx DOCKER_HOST "unix://$XDG_RUNTIME_DIR/docker.sock"

# zoxide
zoxide init fish | source
