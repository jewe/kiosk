#!/usr/bin/env bash
# re-exec with bash when started with sh
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"
# Usage simulation: random clicks, drags, scrolls and keys on the kiosk screen for N minutes
# while sampling the memory of all app processes. Mouse events only (xdotool); a touchscreen
# produces the same clicks in the browser.
#   stress.sh [minutes=10] [events-per-second=2]
# Result: /opt/kiosk/data/stress/<timestamp>.csv and a summary; pass = no app restarts and
# memory growth under 10 % between the first and the last quarter of the run.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="stress"
minutes="${1:-10}"; eps="${2:-2}"
[[ "$minutes" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "minutes must be a number (got '$minutes')"
secs="$(awk -v m="$minutes" 'BEGIN {printf "%d", m*60}')"
[ "$(id -u)" -eq 0 ] || [ "$(id -un)" = "$KIOSK_USER" ] || die "run as root (sudo kioskctl test stress) or as $KIOSK_USER"
export DISPLAY=:0 XAUTHORITY="/home/${KIOSK_USER}/.Xauthority"
xset q >/dev/null 2>&1 || die "X not reachable"
read -r sw sh _ _ < <(/opt/kiosksystem/display/screen-geometry.sh all)
out="${KIOSK_DIR}/data/stress"; mkdir -p "$out"; csv="$out/$(date +%Y%m%d-%H%M%S).csv"
echo "ts,rss_mb,events,restarts" > "$csv"

restarts() { local t=0; for u in $(systemctl list-units --plain --no-legend 'kiosk-*@*.service' | awk '{print $1}'); do t=$((t + $(systemctl show -p NRestarts --value "$u"))); done; echo "$t"; }
rss_mb() { ps -u "$KIOSK_USER" -o rss= 2>/dev/null | awk '{s+=$1} END {printf "%d", s/1024}'; }

end=$(( $(date +%s) + secs )); events=0; last_sample=0; r0="$(restarts)"
log "running ${minutes} min at ${eps} events/s on ${sw}x${sh}, csv: $csv"
while [ "$(date +%s)" -lt "$end" ]; do
    x=$(( RANDOM % sw )); y=$(( RANDOM % sh ))
    case $(( RANDOM % 10 )) in
        0|1|2|3|4) xdotool mousemove "$x" "$y" click 1 ;;
        5|6)       xdotool mousemove "$x" "$y" click --repeat 3 --delay 50 "$(( RANDOM % 2 + 4 ))" ;;   # scroll up/down
        7)         xdotool mousemove "$x" "$y" mousedown 1 mousemove "$(( RANDOM % sw ))" "$(( RANDOM % sh ))" mouseup 1 ;;
        8)         xdotool mousemove "$x" "$y" click 1 key Tab ;;
        9)         xdotool mousemove "$x" "$y" click 1 key Escape ;;
    esac 2>/dev/null
    events=$((events+1))
    now="$(date +%s)"
    if [ $((now - last_sample)) -ge 30 ]; then
        last_sample=$now
        echo "$(date -Is),$(rss_mb),$events,$(( $(restarts) - r0 ))" >> "$csv"
    fi
    sleep "$(awk -v e="$eps" 'BEGIN {printf "%.3f", 1/e}')"
done
echo "$(date -Is),$(rss_mb),$events,$(( $(restarts) - r0 ))" >> "$csv"

# summary: average rss of first quarter vs last quarter
summary="$(awk -F, 'NR>1 {n++; r[n]=$2} END {
    q=int(n/4); if (q<1) q=1
    for(i=1;i<=q;i++) a+=r[i]; for(i=n-q+1;i<=n;i++) b+=r[i]
    a/=q; b/=q; printf "rss first %.0f MB, last %.0f MB, growth %.1f %%", a, b, (b-a)*100/(a>0?a:1)}' "$csv")"
rest=$(( $(restarts) - r0 ))
log "done: $events events, $summary, app restarts: $rest"
logger -t kiosk-stress -- "{\"events\":$events,\"restarts\":$rest,\"summary\":\"$summary\",\"csv\":\"$csv\"}"
growth="$(echo "$summary" | grep -o 'growth [-0-9.]*' | awk '{print int($2)}')"
if [ "$rest" -eq 0 ] && [ "${growth:-0}" -lt 10 ]; then log "PASS"; exit 0; else log "FAIL"; exit 1; fi
