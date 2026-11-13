#!/usr/bin/env bash
# App type "web": Google Chrome or Chromium (deb, no snap) in kiosk mode with hardening policies.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="app:web"
require_root

# the configured browser (chrome.browser) and its policies; also run by `kioskctl apply`
"${KIOSK_SYS}/apps/web/browser.sh" ensure
apt_install nginx unzip curl   # extensions are served from 127.0.0.1:8090 (apps/web/extensions.sh)

install -m 0644 "${KIOSK_SYS}/apps/web/kiosk-web@.service" /etc/systemd/system/
systemctl daemon-reload
log "installed. Add an app of type 'web' to ${KIOSK_CONFIG} and run: sudo kioskctl apply"
