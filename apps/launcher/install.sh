#!/usr/bin/env bash
# App type "launcher": any command, its window placed on the configured screen/geometry.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="app:launcher"
require_root
apt_install xdotool wmctrl
install -m 0644 "${KIOSK_SYS}/apps/launcher/kiosk-launcher@.service" /etc/systemd/system/
systemctl daemon-reload
log "installed. Add an app of type 'launcher' to ${KIOSK_CONFIG} and run: sudo kioskctl apply"
