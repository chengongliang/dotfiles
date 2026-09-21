# zellij 快捷别名与辅助函数

# ─── 基础别名 ───
alias zj 'zellij'                    # 启动/接入默认会话
alias zja 'zellij attach'            # 接入指定会话：zja <name>
alias zjal 'zellij attach --create'  # 接入会话，不存在则创建
alias zjl 'zellij list-sessions'     # 列出所有会话
alias zjk 'zellij kill-session'      # 终止会话：zjk <name>
alias zjr 'zellij run --'            # 新 pane 中运行命令：zjr <cmd>
alias zje 'zellij edit'              # 新 pane 中编辑文件：zje <file>

# ─── fzf 会话切换 ───
# 对齐 tmux 的 fs 函数：fzf 模糊选择会话后 attach
function zjf --description "fzf 选择并 attach zellij 会话"
    zellij list-sessions --short | fzf --height 20% --layout=reverse --border --prompt='zellij> ' | read -l result
    and zellij attach "$result"
end

# ─── 按目录名接入/创建会话 ───
# 以当前目录名作为会话名，会话不存在时自动创建
function zjn --description "以当前目录名接入或创建 zellij 会话"
    zellij attach --create (basename "$PWD")
end
