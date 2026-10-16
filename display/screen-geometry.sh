#!/usr/bin/env bash
# Prints "W H X Y" for a screen name from kiosk.yaml apps[].screen:
#   primary          → the primary xrandr output
#   all              → the whole virtual screen
#   <output name>    → that output
export DISPLAY="${DISPLAY:-:0}"
want="${1:-primary}"
q="$(xrandr --query)"
case "$want" in
    all)     echo "$q" | awk '/^Screen 0/ {gsub(",","",$0); for(i=1;i<=NF;i++) if($i=="current") {print $(i+1), $(i+3), 0, 0; exit}}' ;;
    primary) echo "$q" | awk '/ connected primary / {print $4; exit}' | sed -E 's/([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)/\1 \2 \3 \4/' ;;
    *)       echo "$q" | awk -v o="$want" '$1==o && $2=="connected" {for(i=3;i<=NF;i++) if($i ~ /^[0-9]+x[0-9]+\+/) {print $i; exit}}' | sed -E 's/([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)/\1 \2 \3 \4/' ;;
esac
