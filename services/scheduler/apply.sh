#!/usr/bin/env bash
# schedule: per-day on/off times → kiosk-schedule-on.timer / kiosk-schedule-off.timer
#   schedule:
#     mon-fri: {on: "07:30", off: "19:00"}
#     sat:     {on: "09:00", off: "16:00"}
#   keys: mon tue wed thu fri sat sun, ranges like mon-fri, or daily
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="scheduler"
units=/etc/systemd/system

cal_day() {  # mon-fri → Mon..Fri, daily → *-*-*
    local d="$1" a b
    cap() { local x="${1,,}"; echo "${x^}"; }
    case "$d" in
        daily|'*') echo '*-*-*' ;;
        *-*) a="${d%-*}"; b="${d#*-}"; echo "$(cap "$a")..$(cap "$b")" ;;
        *) cap "$d" ;;
    esac
}

on_specs=(); off_specs=()
while read -r day; do
    [ -n "$day" ] || continue
    [[ "$day" =~ ^(mon|tue|wed|thu|fri|sat|sun|daily)(-(mon|tue|wed|thu|fri|sat|sun))?$ ]] || { warn "schedule: unknown day '$day'"; continue; }
    on="$(cfg ".schedule[\"$day\"].on")"; off="$(cfg ".schedule[\"$day\"].off")"
    cd_="$(cal_day "$day")"
    for t in "$on" "$off"; do [ -z "$t" ] || [[ "$t" =~ ^[0-9]{1,2}:[0-9]{2}$ ]] || { warn "schedule: bad time '$t' for $day"; continue 2; }; done
    [ -n "$on" ]  && on_specs+=("$cd_ $on:00")
    [ -n "$off" ] && off_specs+=("$cd_ $off:00")
done < <(yq -r '.schedule // {} | keys[]' "$KIOSK_CONFIG" 2>/dev/null)

write_timer() {  # write_timer on|off spec...
    local kind="$1"; shift
    {
        echo "[Unit]"; echo "Description=Kiosk schedule: $kind"
        echo; echo "[Timer]"
        for s in "$@"; do echo "OnCalendar=$s"; done
        echo "Persistent=false"; echo "AccuracySec=30s"
        echo; echo "[Install]"; echo "WantedBy=timers.target"
    } | write_file "$units/kiosk-schedule-$kind.timer" || true
    {
        echo "[Unit]"; echo "Description=Kiosk schedule action: $kind"
        echo; echo "[Service]"; echo "Type=oneshot"
        echo "ExecStart=${KIOSK_SYS}/services/scheduler/action.sh $kind"
    } | write_file "$units/kiosk-schedule-$kind.service" || true
}

enabled="$(cfg '.services.scheduler.enabled' false)"
if [ "$enabled" = "true" ] && [ "${#on_specs[@]}" -gt 0 ] && [ "${#off_specs[@]}" -gt 0 ]; then
    for s in "${on_specs[@]}" "${off_specs[@]}"; do
        systemd-analyze calendar "$s" >/dev/null 2>&1 || { warn "invalid calendar spec '$s'"; exit 1; }
    done
    write_timer on "${on_specs[@]}"
    write_timer off "${off_specs[@]}"
    {
        echo "[Unit]"; echo "Description=Kiosk schedule: apply current state after boot"
        echo "After=kiosk.target"
        echo; echo "[Service]"; echo "Type=oneshot"; echo "TimeoutStartSec=120"; echo "ExecStartPre=/bin/sleep 20"
        echo "ExecStart=${KIOSK_SYS}/services/scheduler/action.sh sync"
        echo; echo "[Install]"; echo "WantedBy=multi-user.target"
    } | write_file "$units/kiosk-schedule-sync.service" || true
    systemctl daemon-reload
    systemctl enable --now kiosk-schedule-on.timer kiosk-schedule-off.timer >/dev/null 2>&1
    systemctl enable kiosk-schedule-sync.service >/dev/null 2>&1
    log "on: ${on_specs[*]} | off: ${off_specs[*]} | off_action: $(cfg '.services.scheduler.off_action' screen)"
    "${KIOSK_SYS}/services/scheduler/action.sh" sync || true
else
    [ "$enabled" = "true" ] && warn "scheduler enabled but schedule has no on/off times"
    systemctl disable --now kiosk-schedule-on.timer kiosk-schedule-off.timer >/dev/null 2>&1 || true
    systemctl disable kiosk-schedule-sync.service >/dev/null 2>&1 || true
    rm -f "$units"/kiosk-schedule-*.timer "$units"/kiosk-schedule-*.service
    rm -f "${KIOSK_STATE}/schedule"
    systemctl daemon-reload
fi
