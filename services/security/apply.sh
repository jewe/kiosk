#!/usr/bin/env bash
# security.disable_usb_storage: blacklist the usb-storage module (conflicts with usb_action).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="security"
conf=/etc/modprobe.d/kiosk-usb-storage.conf
if [ "$(cfg '.security.disable_usb_storage' false)" = "true" ]; then
    if [ "$(cfg '.services.usb_action.enabled' false)" = "true" ]; then
        warn "disable_usb_storage and services.usb_action are both on; usb storage stays enabled"
        rm -f "$conf"; exit 1
    fi
    write_file "$conf" <<'M' && log "usb-storage disabled (takes effect for newly plugged devices, fully after reboot)" || true
install usb-storage /bin/false
blacklist usb-storage
M
    modprobe -r usb-storage 2>/dev/null || true
else
    [ -f "$conf" ] && { rm -f "$conf"; log "usb-storage enabled again"; } || true
fi
