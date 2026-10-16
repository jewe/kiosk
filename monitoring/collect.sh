#!/usr/bin/env bash
# Collects one JSON line of health metrics. `--log` writes it to the journal (tag kiosk-monitor).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

num() { local v="${1:-}"; [[ "$v" =~ ^-?[0-9]+([.][0-9]+)?$ ]] && printf '%s' "$v" || printf 'null'; }

# temperatures and fans from lm-sensors (json), first sensible values
sj="$(sensors -j 2>/dev/null || echo '{}')"
cpu_temp="$(echo "$sj" | jq -r '[.. | objects | to_entries[] | select(.key | test("^(Package id 0|Tctl|Tdie|Core 0|temp1)$")) | .value | objects | to_entries[] | select(.key | test("_input$")) | .value] | first // empty' 2>/dev/null)"
fan="$(echo "$sj" | jq -r '[.. | objects | to_entries[] | select(.key | test("^fan[0-9]*$")) | .value | objects | to_entries[] | select(.key | test("_input$")) | .value] | map(select(. > 0)) | first // empty' 2>/dev/null)"
gpu_temp=""; gpu_util=""
if command -v nvidia-smi >/dev/null; then
    read -r gpu_temp gpu_util < <(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ',' | head -1) || true
fi
throttle="$(cat /sys/devices/system/cpu/cpu0/thermal_throttle/core_throttle_count 2>/dev/null)"
load="$(cut -d' ' -f1 /proc/loadavg)"
mem_pct="$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {if (t) printf "%.0f", (t-a)*100/t}' /proc/meminfo)"
disk_root="$(df --output=pcent / | tail -1 | tr -dc '0-9')"
disk_data="$(df --output=pcent "$KIOSK_DIR" 2>/dev/null | tail -1 | tr -dc '0-9')"
uptime_s="$(cut -d. -f1 /proc/uptime)"
restarts="$(for u in $(systemctl list-units --plain --no-legend 'kiosk-*@*.service' 2>/dev/null | awk '{print $1}'); do
    printf '"%s":%s,' "${u#kiosk-}" "$(systemctl show -p NRestarts --value "$u" 2>/dev/null || echo 0)"; done)"
restarts="{${restarts%,}}"
session="$(systemctl is-active kiosk-session.service 2>/dev/null)"

line="$(jq -c -n \
    --arg ts "$(date -Is)" --arg host "$(hostname)" --arg session "$session" \
    --argjson cpu_temp "$(num "$cpu_temp")" --argjson gpu_temp "$(num "$gpu_temp")" --argjson gpu_util "$(num "$gpu_util")" \
    --argjson fan "$(num "$fan")" --argjson throttle "$(num "$throttle")" --argjson load "$(num "$load")" \
    --argjson mem_pct "$(num "$mem_pct")" --argjson disk_root "$(num "$disk_root")" --argjson disk_data "$(num "$disk_data")" \
    --argjson uptime "$(num "$uptime_s")" --argjson restarts "$restarts" \
    '{ts:$ts,host:$host,cpu_temp:$cpu_temp,gpu_temp:$gpu_temp,gpu_util:$gpu_util,fan:$fan,throttle:$throttle,load:$load,mem_pct:$mem_pct,disk_root:$disk_root,disk_data:$disk_data,uptime:$uptime,session:$session,restarts:$restarts}')"

if [ "${1:-}" = "--log" ]; then
    logger -t kiosk-monitor -- "$line"
else
    echo "$line"
fi
