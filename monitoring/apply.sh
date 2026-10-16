#!/usr/bin/env bash
# Metrics collection runs always; the heartbeat only when services.monitoring is enabled.
# services.monitoring.interval sets both (default 5m).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="monitoring"
interval="$(cfg '.services.monitoring.interval' 5m)"
[[ "$interval" =~ ^[0-9]+(s|m|h|min)?$ ]] || { warn "monitoring.interval '$interval' invalid, using 5m"; interval=5m; }
install -m 0644 "${KIOSK_SYS}/monitoring/kiosk-monitor.service" /etc/systemd/system/
sed "s/^OnUnitActiveSec=.*/OnUnitActiveSec=${interval}/" "${KIOSK_SYS}/monitoring/kiosk-monitor.timer" | write_file /etc/systemd/system/kiosk-monitor.timer || true
systemctl daemon-reload
systemctl enable --now kiosk-monitor.timer >/dev/null 2>&1
if [ "$(cfg '.services.monitoring.enabled' false)" = "true" ]; then
    log "metrics every $interval, heartbeat to $(cfg '.services.monitoring.url' '(no url!)')"
else
    log "metrics every $interval, heartbeat off"
fi
