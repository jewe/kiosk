#!/usr/bin/env bash
# Scheduler actions. Called by the kiosk-schedule-* units and by apply.
#   action.sh on | off | sync
# services.scheduler.off_action: screen (DPMS off, default) | apps (stop app units) | shutdown (poweroff + rtcwake)
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="scheduler"
what="${1:?on|off|sync}"
off_action="$(cfg '.services.scheduler.off_action' screen)"
uid="$(id -u "$KIOSK_USER" 2>/dev/null || echo 1001)"
xk() { sudo -u "$KIOSK_USER" env DISPLAY=:0 XAUTHORITY="/home/${KIOSK_USER}/.Xauthority" "$@"; }

# next_elapse <timer>  → epoch seconds of the timer's next run, empty when unknown
next_elapse() {
    local v; v="$(systemctl show -p NextElapseUSecRealtime --value "$1" 2>/dev/null)"
    [ -n "$v" ] && [ "$v" != "n/a" ] && date -d "$v" +%s 2>/dev/null || true
}

do_on() {
    log "on ($off_action)"
    # --no-block: this may run from inside a unit that kiosk.target itself waits for
    systemctl start --no-block kiosk.target 2>/dev/null || true
    xk xset dpms force on 2>/dev/null; xk xset s reset 2>/dev/null
    echo on > "${KIOSK_STATE}/schedule"
}
do_off() {
    log "off ($off_action)"
    echo off > "${KIOSK_STATE}/schedule"
    case "$off_action" in
        screen)   xk xset dpms force off 2>/dev/null ;;
        apps)     for u in $(systemctl list-units --plain --no-legend 'kiosk-*@*.service' | awk '{print $1}'); do systemctl stop "$u"; done
                  xk xset dpms force off 2>/dev/null ;;
        shutdown) local next; next="$(next_elapse kiosk-schedule-on.timer)"
                  if [ -n "$next" ]; then rtcwake -m no -t "$next" >/dev/null 2>&1 && log "wake set for $(date -d "@$next")"; fi
                  systemctl poweroff ;;
        *) warn "unknown off_action '$off_action'" ;;
    esac
}
do_sync() {
    # which event is next? if "off" comes before "on" we are inside an on-period
    local non noff; non="$(next_elapse kiosk-schedule-on.timer)"; noff="$(next_elapse kiosk-schedule-off.timer)"
    [ -n "$non" ] && [ -n "$noff" ] || { log "sync: timers not active"; return 0; }
    if [ "$noff" -lt "$non" ]; then
        [ "$(cat "${KIOSK_STATE}/schedule" 2>/dev/null)" = "on" ] || do_on
    else
        [ "$off_action" = "shutdown" ] && { log "sync: in off-period, not shutting down automatically"; return 0; }
        do_off
    fi
}
case "$what" in
    on) do_on ;; off) do_off ;; sync) do_sync ;;
    *) exit 2 ;;
esac
