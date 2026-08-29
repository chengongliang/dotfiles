#!/usr/bin/env bash
# lock_status.sh — Win11-style lock screen status icons.
# Outputs Segoe MDL2 Assets glyphs for Wi-Fi / volume / battery, or the date.
# Usage: lock_status.sh wifi | vol | bat | date
set -u

MDL2_WIFI_UP=$'\ue701'     # World / 网络（已连接）
MDL2_WIFI_DOWN=$'\ue702'   # Globe / 无网络
MDL2_VOL=$'\ue767'         # Volume 喇叭
MDL2_MUTE=$'\ue74f'        # Volume Mute
MDL2_CHARGING=$'\ue8bd'    # 电池（带闪电）
# 电池 0%..100% -> E850..E85A
bat_glyph() {
    local n=$1
    [ "$n" -gt 10 ] && n=10
    [ "$n" -lt 0 ] && n=0
    local esc
    printf -v esc '\\U%08X' $((0xE850 + n))
    printf '%b' "$esc"
}

case "${1:-}" in
    wifi)
        if nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | grep -q ':wifi:connected'; then
            printf '%s' "$MDL2_WIFI_UP"
        else
            printf '%s' "$MDL2_WIFI_DOWN"
        fi
        ;;
    vol)
        v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
        if [[ "$v" == *MUTED* ]] || [[ "$v" =~ Volume:\ *0\.0(0)?([[:space:]]|$) ]]; then
            printf '%s' "$MDL2_MUTE"
        else
            printf '%s' "$MDL2_VOL"
        fi
        ;;
    bat)
        dev=$(upower -e 2>/dev/null | grep -m1 '/battery_')
        [ -z "$dev" ] && { printf '%s' "$MDL2_CHARGING"; exit 0; }
        pct=$(upower -i "$dev" 2>/dev/null | awk -F: '/percentage/{gsub(/[ %]/,"",$2); print $2}')
        st=$(upower -i "$dev" 2>/dev/null | awk -F: '/state/{gsub(/ /,"",$2); print $2}')
        [ -z "$pct" ] && { printf '%s' "$MDL2_CHARGING"; exit 0; }
        if [ "$st" = "charging" ] || [ "$st" = "fully-charged" ]; then
            printf '%s' "$MDL2_CHARGING"
        else
            bat_glyph $((pct / 10))
        fi
        ;;
    date)
        LC_TIME=zh_CN.UTF-8 date "+%Y年%-m月%-d日 %A"
        ;;
    bar)
        # 底部状态栏：Wi-Fi + 音量 + 电池（Win11 锁屏底部图标组）
        wifi_up=$MDL2_WIFI_UP; wifi_dn=$MDL2_WIFI_DOWN
        if nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | grep -q ':wifi:connected'; then
            w=$wifi_up
        else
            w=$wifi_dn
        fi
        v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
        if [[ "$v" == *MUTED* ]] || [[ "$v" =~ Volume:\ *0\.0(0)?([[:space:]]|$) ]]; then
            vol=$MDL2_MUTE
        else
            vol=$MDL2_VOL
        fi
        dev=$(upower -e 2>/dev/null | grep -m1 '/battery_')
        if [ -n "$dev" ]; then
            st=$(upower -i "$dev" 2>/dev/null | awk -F: '/state/{gsub(/ /,"",$2); print $2}')
            if [ "$st" = "charging" ] || [ "$st" = "fully-charged" ]; then
                bat=$MDL2_CHARGING
            else
                pct=$(upower -i "$dev" 2>/dev/null | awk -F: '/percentage/{gsub(/[ %]/,"",$2); print $2}')
                bat=$(bat_glyph $((pct / 10)))
            fi
        else
            bat=$MDL2_CHARGING
        fi
        printf '%2s  %2s  %2s' "$w" "$vol" "$bat"
        ;;
    *) exit 1 ;;
esac
