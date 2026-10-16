#!/usr/bin/env bash
# Applies display.outputs and touch.output from kiosk.yaml with xrandr/xinput.
# Runs as the kiosk user with DISPLAY set; safe to re-run while apps are up.
set -uo pipefail
source /opt/kiosksystem/lib/common.sh
LOG_TAG="display"
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-/home/${KIOSK_USER}/.Xauthority}"

n="$(cfg '.display.outputs | length' 0)"
if [ "$n" = "0" ]; then
    xrandr --auto
    # X may mark a disconnected output as primary; make the first connected one primary
    first="$(xrandr --query | awk '$2=="connected" {print $1; exit}')"
    if [ -n "$first" ] && ! xrandr --query | grep -q ' connected primary '; then
        xrandr --output "$first" --primary && log "primary output: $first"
    fi
else
    args=()
    for ((i=0; i<n; i++)); do
        name="$(cfg ".display.outputs[$i].name")"
        [ -n "$name" ] || continue
        args+=(--output "$name")
        enabled="$(cfg ".display.outputs[$i].enabled" true)"
        if [ "$enabled" = "false" ]; then args+=(--off); continue; fi
        mode="$(cfg ".display.outputs[$i].mode")";       [ -n "$mode" ] && args+=(--mode "$mode") || args+=(--auto)
        pos="$(cfg ".display.outputs[$i].pos")";         [ -n "$pos" ] && args+=(--pos "$pos")
        rot="$(cfg ".display.outputs[$i].rotate")";      [ -n "$rot" ] && args+=(--rotate "$rot")
        rate="$(cfg ".display.outputs[$i].rate")";       [ -n "$rate" ] && args+=(--rate "$rate")
        tf="$(cfg ".display.outputs[$i].transform")";    [ -n "$tf" ] && args+=(--transform "$tf")
        primary="$(cfg ".display.outputs[$i].primary" false)"; [ "$primary" = "true" ] && args+=(--primary)
    done
    log "xrandr ${args[*]}"
    xrandr "${args[@]}" || warn "xrandr failed"
fi

# touchscreen → output
touch_out="$(cfg '.touch.output')"
if [ -n "$touch_out" ]; then
    while read -r id; do
        [ -n "$id" ] || continue
        xinput --map-to-output "$id" "$touch_out" && log "touch device $id mapped to $touch_out"
    done < <(xinput list --id-only 2>/dev/null | while read -r id; do
                 xinput list-props "$id" 2>/dev/null | grep -q 'libinput Calibration Matrix' && \
                 xinput list --name-only "$id" | grep -qiv 'pen\|stylus' && echo "$id"; done)
fi
exit 0
