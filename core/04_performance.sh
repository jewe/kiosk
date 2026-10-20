#!/usr/bin/env bash
# CPU governor/EPP at boot (services/performance/apply.sh --boot), no sleep, low swappiness, basic sysctl.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="performance"

systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1 || true

write_file /etc/systemd/system/kiosk-cpufreq.service <<'UNIT' || true
[Unit]
Description=Kiosk: CPU governor, energy preference and GPU clock floor
DefaultDependencies=no
After=sysinit.target
Before=kiosk-session.service

[Service]
Type=oneshot
ExecStart=/opt/kiosksystem/services/performance/apply.sh --boot

[Install]
WantedBy=sysinit.target
UNIT
systemctl daemon-reload
systemctl disable kiosk-cpufreq.service >/dev/null 2>&1 || true
systemctl enable kiosk-cpufreq.service >/dev/null

write_file /etc/sysctl.d/90-kiosk.conf <<'SYS' || true
vm.swappiness = 10
vm.dirty_writeback_centisecs = 1500
kernel.sysrq = 0
SYS
sysctl -q --system >/dev/null
log "done"
