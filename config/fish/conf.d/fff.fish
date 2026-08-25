# FFF (pi-fff 扩展) 配置
# 从 $HOME 启动 pi 时不再后台索引整棵 home 树，避免大目录扫描拖慢启动并消除警告。
# 具体项目目录内的 fffind / ffgrep 照常工作。
# 等价 CLI flag: --fff-enable-home-scan=false
set -gx FFF_ENABLE_HOME_SCAN 0
