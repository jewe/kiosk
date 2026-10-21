#!/usr/bin/env bash
# Health check for web/static apps (services.health). "Broken" means one of:
#   window  no visible X window with class kiosk-<name> although the unit is active
#   title   the window title is empty, "Untitled", "about:blank" or an error page (Chrome renderer gone, blank window)
#   http    static app: nginx on 127.0.0.1:<port>/ does not answer 200
#   screen  the window area is one flat colour: pixel standard deviation below services.health.min_stddev
# Action: restart the app unit; after 3 restarts within 30 minutes restart the whole session once;
# every event goes to the journal (tag kiosk-health) and, when Telegram is enabled, a screenshot is sent.
#   check.sh [--dry-run]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="health"
dry=0; [ "${1:-}" = "--dry-run" ] && dry=1
XENV=(DISPLAY=:0 XAUTHORITY="/home/${KIOSK_USER}/.Xauthority")
xk() { sudo -u "$KIOSK_USER" env "${XENV[@]}" "$@"; }
checks="$(cfg '(.services.health.checks // ["window","title","http"]) | join(" ")')"
min_sd="$(cfg '.services.health.min_stddev' 3)"
hist="${KIOSK_STATE}/health-restarts"; mkdir -p "$KIOSK_STATE"
has() { [[ " $checks " == *" $1 "* ]]; }
xk xset q >/dev/null 2>&1 || { log "X not running, nothing to check"; exit 0; }
[ "$(fgconsole 2>/dev/null)" = 1 ] || { log "text console active, skipping"; exit 0; }

event() {  # event <app> <reason>
    logger -t kiosk-health -- "{\"ts\":\"$(date -Is)\",\"app\":\"$1\",\"reason\":\"$2\",\"action\":\"$3\"}"
    warn "$1: $2 → $3"
}
count="$(cfg '.apps | length' 0)"
for ((i=0; i<count; i++)); do
    n="$(cfg ".apps[$i].name")"; t="$(cfg ".apps[$i].type")"
    [[ "$t" = web || "$t" = static ]] || continue
    unit="kiosk-${t}@${n}.service"
    systemctl is-active "$unit" >/dev/null 2>&1 || continue     # not running = not our problem (stopped by schedule or admin)
    started="$(systemctl show -p ActiveEnterTimestampMonotonic --value "$unit")"
    now="$(( $(cut -d. -f1 /proc/uptime) * 1000000 ))"
    [ $(( now - started )) -gt 45000000 ] || continue           # younger than 45 s: still starting
    reason=""; title=""; code=""; sd=""
    wid="$(xk xdotool search --onlyvisible --class "kiosk-${n}" 2>/dev/null | head -1)"
    if has window && [ -z "$wid" ]; then reason="no window"; fi
    if [ -z "$reason" ] && has title && [ -n "$wid" ]; then
        title="$(xk xdotool getwindowname "$wid" 2>/dev/null)"
        case "$title" in ""|Untitled*|about:blank*|"Aw, Snap"*|*"is not available"*|*"can't be reached"*|*"No internet"*) reason="window title '$title'" ;; esac
    fi
    if [ -z "$reason" ] && has http && [ "$t" = static ]; then
        port="$(cfg ".apps[$i].port" 8080)"
        code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "http://127.0.0.1:${port}/" 2>/dev/null)"
        [ "$code" = 200 ] || reason="nginx answered $code"
    fi
    if [ -z "$reason" ] && has screen && [ -n "$wid" ]; then
        read -r x y w h < <(xk xdotool getwindowgeometry --shell "$wid" 2>/dev/null | awk -F= '/^X=|^Y=|^WIDTH=|^HEIGHT=/ {printf "%s ", $2}') || true
        shot="$(mktemp --suffix=.png)"; chown "$KIOSK_USER" "$shot"     # scrot runs as the kiosk user
        if xk scrot -o -a "${x:-0},${y:-0},${w:-100},${h:-100}" "$shot" 2>/dev/null; then
            sd="$(convert "$shot" -colorspace Gray -format '%[fx:standard_deviation*255]' info: 2>/dev/null | cut -d. -f1)"
            [ -n "$sd" ] && [ "${sd:-0}" -lt "$min_sd" ] && reason="flat screen (stddev $sd < $min_sd)"
        fi
        rm -f "$shot"
    fi
    [ "$dry" = 1 ] && log "$n: window=${wid:-none} title='${title}' http=${code:-skipped} stddev=${sd:-skipped}"
    [ -n "$reason" ] || continue
    # restart, or escalate to the session after 3 restarts within 30 minutes
    nowts="$(date +%s)"; recent="$( { [ -f "$hist" ] && awk -v t="$nowts" -v a="$n" '$1 > t-1800 && $2 == a' "$hist"; } | wc -l)"
    if [ "$dry" = 1 ]; then event "$n" "$reason" "dry-run"; continue; fi
    [ "$(cfg '.services.telegram.enabled' false)" = true ] && "${KIOSK_SYS}/services/telegram/send.sh" "" "health: $n $reason" >/dev/null 2>&1 || true
    if [ "$recent" -ge 3 ]; then
        event "$n" "$reason" "session restart (${recent} app restarts in 30 min)"
        : > "$hist"; systemctl restart kiosk-session.service
    else
        event "$n" "$reason" "restart"
        echo "$nowts $n" >> "$hist"; systemctl restart "$unit"
    fi
done
[ -f "$hist" ] && awk -v t="$(date +%s)" '$1 > t-86400' "$hist" > "$hist.tmp" && mv "$hist.tmp" "$hist"
exit 0
