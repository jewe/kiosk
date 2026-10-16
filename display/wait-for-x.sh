#!/usr/bin/env bash
# ExecStartPre for app units: waits until the X server answers (max 30 s).
export DISPLAY="${DISPLAY:-:0}"
for _ in $(seq 1 60); do
    xset q >/dev/null 2>&1 && exit 0
    sleep 0.5
done
echo "X server on $DISPLAY not reachable" >&2
exit 1
