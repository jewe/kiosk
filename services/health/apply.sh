#!/usr/bin/env bash
# services.health: periodic check that every web/static app really shows something; restarts it if not.
#   enabled: false | true
#   interval: 2m
#   checks: [window, title, http, screen]     default window,title,http
#   min_stddev: 3                             screen check: minimum pixel standard deviation (0-255 scale)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="health"
install -m 0644 "${KIOSK_SYS}/services/health/kiosk-health.service" /etc/systemd/system/
if [ "$(cfg '.services.health.enabled' false)" != "true" ]; then
    systemctl disable --now kiosk-health.timer >/dev/null 2>&1 || true
    systemctl daemon-reload
    exit 0
fi
interval="$(cfg '.services.health.interval' 2m)"
[[ "$interval" =~ ^[0-9]+(s|m|h|min)?$ ]] || { warn "health.interval '$interval' invalid, using 2m"; interval=2m; }
checks="$(cfg '(.services.health.checks // ["window","title","http"]) | join(" ")')"
[[ " $checks " == *" screen "* ]] && { command -v convert >/dev/null || apt_install imagemagick; }
sed "s/^OnUnitActiveSec=.*/OnUnitActiveSec=${interval}/" "${KIOSK_SYS}/services/health/kiosk-health.timer" | write_file /etc/systemd/system/kiosk-health.timer || true
systemctl daemon-reload
systemctl enable --now kiosk-health.timer >/dev/null 2>&1
log "health checks every $interval: $checks"
