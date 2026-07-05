# fnm — 自动切换 node 版本 + 国内镜像加速下载
set -gx FNM_NODE_DIST_MIRROR "https://npmmirror.com/mirrors/node"
fnm env --use-on-cd --shell fish | source
