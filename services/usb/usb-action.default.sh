#!/usr/bin/env bash
# Default USB-stick action, copied to /opt/kiosk/usb-action.sh (edit there). Runs as root.
#   $1 = mount point of the stick (read/write), $2 = device
# Default: write a status report with recent logs onto the stick.
set -uo pipefail
mnt="$1"
out="$mnt/kiosk-$(hostname)-$(date +%Y%m%d-%H%M).txt"
{
    kioskctl status
    echo; echo "=== journal (last 200 lines)"
    journalctl -b -n 200 --no-pager
} > "$out" 2>&1
echo "status written to $out"
