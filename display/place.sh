#!/usr/bin/env bash
# Window placement helpers.
#   place.sh geometry <screen> <geometry>            → prints "W H X Y" (absolute) for screen+geometry
#   place.sh window <pid> <wm_class> <screen> <geometry>   → waits for the window (15 s) and places it
export DISPLAY="${DISPLAY:-:0}"
mode="${1:?mode}"

geometry_for() {
    local screen="$1" geom="$2" w h x y
    read -r w h x y < <(/opt/kiosksystem/display/screen-geometry.sh "$screen") || true
    [ -n "${w:-}" ] || { w=1920; h=1080; x=0; y=0; }
    if [ "$geom" != "fullscreen" ] && [[ "$geom" =~ ^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$ ]]; then
        w="${BASH_REMATCH[1]}"; h="${BASH_REMATCH[2]}"
        x=$(( x + BASH_REMATCH[3] )); y=$(( y + BASH_REMATCH[4] ))
    fi
    echo "$w $h $x $y"
}

case "$mode" in
    geometry) geometry_for "${2:-primary}" "${3:-fullscreen}" ;;
    window)
        pid="${2:?pid}"; cls="${3:-}"; screen="${4:-primary}"; geom="${5:-fullscreen}"
        wid=""
        for _ in $(seq 1 30); do
            if [ -n "$cls" ]; then
                wid="$(xdotool search --onlyvisible --class "$cls" 2>/dev/null | head -1)"
            else
                wid="$(xdotool search --onlyvisible --pid "$pid" 2>/dev/null | head -1)"
            fi
            [ -n "$wid" ] && break
            sleep 0.5
        done
        [ -n "$wid" ] || exit 1
        read -r w h x y < <(geometry_for "$screen" "$geom")
        wmctrl -i -r "$wid" -b remove,fullscreen,maximized_vert,maximized_horz
        xdotool windowmove "$wid" "$x" "$y" windowsize "$wid" "$w" "$h"
        if [ "$geom" = "fullscreen" ]; then
            wmctrl -i -r "$wid" -b add,fullscreen
        fi
        xdotool windowactivate "$wid" 2>/dev/null || true
        ;;
    *) echo "usage: place.sh geometry|window ..." >&2; exit 2 ;;
esac
