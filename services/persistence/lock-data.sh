#!/usr/bin/env bash
# Mounts a tmpfs-backed overlay over /opt/kiosk: the volume underneath stays read-only,
# all writes go to RAM and vanish at reboot. Overlayfs may be mounted over its own lowerdir.
set -euo pipefail
d=/opt/kiosk
findmnt -n "$d" >/dev/null || exit 0                     # plain directory on root: root overlay covers it
findmnt -n -o FSTYPE "$d" | grep -q overlay && exit 0      # already done
mount -o remount,ro "$d"
mkdir -p /run/kiosk-overlay/upper /run/kiosk-overlay/work
mount -t overlay overlay -o "lowerdir=$d,upperdir=/run/kiosk-overlay/upper,workdir=/run/kiosk-overlay/work" "$d"
