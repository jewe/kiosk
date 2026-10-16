#!/usr/bin/env bash
# Mounts the stick partition, runs /opt/kiosk/usb-action.sh <mountpoint> <device>, unmounts.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="usb"
dev="/dev/${1:?partition}"
[ "$(cfg '.services.usb_action.enabled' false)" = "true" ] || exit 0
action="${KIOSK_DIR}/usb-action.sh"
[ -x "$action" ] || { warn "no executable $action"; exit 0; }
mnt="/run/kiosk/usb/$(basename "$dev")"
mkdir -p "$mnt"
mount -o noexec,nosuid,nodev "$dev" "$mnt" || { warn "cannot mount $dev"; rmdir "$mnt"; exit 0; }
log "$dev mounted at $mnt, running usb-action.sh"
"$action" "$mnt" "$dev" || warn "usb-action.sh failed"
sync; umount "$mnt"; rmdir "$mnt"
log "$dev done"
