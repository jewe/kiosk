#!/usr/bin/env bash
# App type "video": mpv playing a file, a directory (playlist) or a URL in a loop, hardware decoded.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="app:video"
require_root
apt_update_once
apt_install mpv
install -m 0644 "${KIOSK_SYS}/apps/video/kiosk-video@.service" /etc/systemd/system/
systemctl daemon-reload
log "installed. Add an app of type 'video' to ${KIOSK_CONFIG} and run: sudo kioskctl apply"
