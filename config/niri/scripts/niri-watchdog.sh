#!/usr/bin/env bash
# ============================================================
#  niri-watchdog.sh — 检测 niri 卡死/显示管线挂掉，抓取现场
#
#  背景：本机 (ASUS ROG / R9 8945HS + 780M DCN3.1.4 + RTX4060)
#  在 s2idle 唤醒后 amdgpu 的 DCN 会进入半坏状态，niri 可能卡在
#  DRM ioctl 上，表现为「屏幕全红 + 输入无响应但系统仍存活」。
#
#  本脚本定期用 niri IPC 探活；连续失败即判定卡死，抓取内核/GPU/
#  线程栈现场，便于确定 niri 是否卡在不可中断的 D 状态。
#
#  环境变量：
#    AUTO_RECOVER=1   卡死后自动重启 niri.service（会丢失当前所有窗口）
#    INTERVAL=5       探活间隔秒
#    THRESHOLD=3      连续失败多少次判定卡死
# ============================================================
set -u

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/niri-watchdog"
mkdir -p "$STATE_DIR"
LOG="$STATE_DIR/events.log"

INTERVAL="${INTERVAL:-5}"
THRESHOLD="${THRESHOLD:-3}"
AUTO_RECOVER="${AUTO_RECOVER:-0}"

fails=0
log() { printf '%s %s\n' "$(date -Is)" "$*" | tee -a "$LOG" >&2; }

collect_scene() {
    local ts pid out
    ts=$(date +%Y%m%d-%H%M%S)
    out="$STATE_DIR/crash-$ts"
    mkdir -p "$out"
    pid=$(pgrep -x niri | head -1 || true)
    log "== 抓取现场 -> $out (niri pid=${pid:-none}) =="

    # 1) 进程/线程状态：D 状态 = 卡在内核里，SIGKILL 也杀不掉
    if [ -n "$pid" ]; then
        ps -L -o pid,tid,stat,wchan:40,pcpu,etime,comm -p "$pid" >"$out/threads.txt" 2>&1 || true
        grep -E '^(State|Threads|voluntary_ctxt|nonvoluntary_ctxt)' "/proc/$pid/status" >"$out/status.txt" 2>&1 || true
        { echo "--- /proc/$pid/stack (内核栈) ---"; sudo -n cat "/proc/$pid/stack" 2>&1; } >>"$out/status.txt" 2>&1
        { echo "--- /proc/$pid/wchan ---"; cat "/proc/$pid/wchan" 2>&1; echo; } >>"$out/status.txt" 2>&1
    fi

    # 2) 内核 / DRM / amdgpu
    sudo -n dmesg >"$out/dmesg.txt" 2>&1 || true
    journalctl -b -k --no-pager -n 400 >"$out/journal-kernel.txt" 2>&1 || true
    journalctl -b --no-pager -n 400 >"$out/journal-all.txt" 2>&1 || true

    # 3) DRM/GPU debugfs 快照
    {
        for f in /sys/kernel/debug/dri/*/amdgpu_ring_gfx /sys/kernel/debug/dri/*/amdgpu_gpu_recover \
                 /sys/kernel/debug/dri/*/*/psr_state /sys/kernel/debug/dri/*/*/psr_capability \
                 /sys/kernel/debug/dri/*/amdgpu_dm_dcc_en; do
            [ -e "$f" ] || continue
            echo "--- $f ---"; sudo -n cat "$f" 2>&1
        done
        echo "--- nvidia-smi ---"; nvidia-smi 2>&1 | head -20
    } >"$out/gpu.txt" 2>&1

    # 4) 会话 & niri 自述
    timeout 4 niri msg --json outputs >"$out/niri-outputs.json" 2>&1 || true
    loginctl list-sessions >"$out/sessions.txt" 2>&1 || true

    # 5) 最近一次唤醒记录（定位是否 resume 触发）
    journalctl -b --no-pager 2>/dev/null | grep -iE "PM: suspend exit|resuming session|Page flip commit failed|lttpr|REG_WAIT" | tail -40 \
        >"$out/resume-history.txt" 2>&1 || true

    log "== 现场抓取完成 =="
}

log "watchdog 启动 (interval=${INTERVAL}s threshold=${THRESHOLD} auto_recover=${AUTO_RECOVER})"
while true; do
    if timeout 4 niri msg --json outputs >/dev/null 2>&1; then
        [ "$fails" -ne 0 ] && log "niri 恢复响应"
        fails=0
    else
        fails=$((fails + 1))
        log "niri 无响应 (连续 $fails/$THRESHOLD)"
        if [ "$fails" -ge "$THRESHOLD" ]; then
            collect_scene
            fails=0
            if [ "$AUTO_RECOVER" = "1" ]; then
                log "尝试自动恢复：systemctl --user restart niri.service"
                systemctl --user restart niri.service >>"$LOG" 2>&1 \
                    && log "niri.service 重启指令已下发" \
                    || log "自动恢复失败（niri 可能卡在 D 状态）"
            fi
        fi
    fi
    sleep "$INTERVAL"
done
