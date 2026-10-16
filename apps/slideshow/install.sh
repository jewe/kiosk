#!/usr/bin/env bash
# App type "slideshow": images from a directory, each shown for `interval` seconds (mpv).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="app:slideshow"
require_root
apt_update_once
apt_install mpv
install -m 0644 "${KIOSK_SYS}/apps/slideshow/kiosk-slideshow@.service" /etc/systemd/system/
systemctl daemon-reload
log "installed. Add an app of type 'slideshow' to ${KIOSK_CONFIG} and run: sudo kioskctl apply"
