#!/usr/bin/env bash
# App type "static": a static site (e.g. `nuxt generate` output) served by nginx on 127.0.0.1,
# shown fullscreen in Chrome. Optional git repo with update at boot.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="app:static"
require_root

[ -f /etc/systemd/system/kiosk-web@.service ] || bash "${KIOSK_SYS}/apps/web/install.sh"
apt_update_once
apt_install nginx git
rm -f /etc/nginx/sites-enabled/default
systemctl enable nginx >/dev/null

install -m 0644 "${KIOSK_SYS}/apps/static/kiosk-static@.service" /etc/systemd/system/
install -m 0644 "${KIOSK_SYS}/apps/static/kiosk-content-update@.service" /etc/systemd/system/
systemctl daemon-reload
log "installed. Add an app of type 'static' to ${KIOSK_CONFIG} and run: sudo kioskctl apply"
