#!/usr/bin/env bash
# Remove what a kiosk must not have: snap, unattended upgrades, cloud-init after first boot.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="cleanup"

if dpkg -l snapd 2>/dev/null | grep -q '^ii'; then
    log "removing snap"
    for s in $(snap list 2>/dev/null | awk 'NR>1 && $1!="snapd" && $1!="core*" {print $1}'); do
        snap remove --purge "$s" || true
    done
    systemctl stop snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
    apt-get purge -y snapd
    rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /root/snap
fi
# keep apt from reinstalling snapd as a dependency
write_file /etc/apt/preferences.d/nosnap.pref <<'PREF' || true
Package: snapd
Pin: release a=*
Pin-Priority: -10
PREF

if dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii'; then
    log "removing unattended-upgrades"
    systemctl disable --now unattended-upgrades 2>/dev/null || true
    apt-get purge -y unattended-upgrades
fi
write_file /etc/apt/apt.conf.d/20auto-upgrades <<'APT' || true
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
APT

# cloud-init did its job during autoinstall; stop it from running at every boot
if [ -d /etc/cloud ] && [ ! -f /etc/cloud/cloud-init.disabled ]; then
    touch /etc/cloud/cloud-init.disabled
    log "cloud-init disabled"
fi

# motd noise and apt news
rm -f /etc/update-motd.d/10-help-text /etc/update-motd.d/50-motd-news /etc/update-motd.d/91-contract-ua-esm-status 2>/dev/null || true
systemctl disable --now motd-news.timer apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

apt-get autoremove -y --purge
log "done"
