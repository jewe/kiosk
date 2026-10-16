#!/usr/bin/env bash
# Xorg + openbox session without a display manager, GPU drivers, tearing fixes, systemd units.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="display"
require_root

apt_install \
    xserver-xorg-core xserver-xorg-legacy xinit x11-xserver-utils xinput \
    xserver-xorg-input-libinput xserver-xorg-video-all \
    openbox feh wmctrl xdotool unclutter-xfixes \
    mesa-utils libgl1-mesa-dri va-driver-all vainfo \
    fonts-dejavu-core dbus-x11

# allow the kiosk user to start Xorg from a systemd service
write_file /etc/X11/Xwrapper.config <<'XW' || true
allowed_users=anybody
needs_root_rights=yes
XW

# --- GPU drivers and tearing fixes ---
mkdir -p /etc/X11/xorg.conf.d
rm -f /etc/X11/xorg.conf.d/20-kiosk-*.conf
if has_gpu nvidia; then
    log "nvidia GPU detected"
    apt_install ubuntu-drivers-common
    if ! dpkg -l 2>/dev/null | grep -q '^ii  nvidia-driver-'; then
        log "installing recommended nvidia driver"
        ubuntu-drivers install || warn "nvidia driver install failed; check 'ubuntu-drivers devices'"
    fi
    install -m 0644 "${KIOSK_SYS}/display/xorg.conf.d/20-kiosk-nvidia.conf" /etc/X11/xorg.conf.d/
elif has_gpu amd; then
    log "AMD GPU detected"
    install -m 0644 "${KIOSK_SYS}/display/xorg.conf.d/20-kiosk-amdgpu.conf" /etc/X11/xorg.conf.d/
elif has_gpu intel; then
    log "Intel GPU detected"
    apt_install intel-media-va-driver-non-free 2>/dev/null || apt_install intel-media-va-driver
    install -m 0644 "${KIOSK_SYS}/display/xorg.conf.d/20-kiosk-modesetting.conf" /etc/X11/xorg.conf.d/
else
    log "no known GPU detected (VM?), using modesetting"
    install -m 0644 "${KIOSK_SYS}/display/xorg.conf.d/20-kiosk-modesetting.conf" /etc/X11/xorg.conf.d/
fi
install -m 0644 "${KIOSK_SYS}/display/xorg.conf.d/10-kiosk-serverflags.conf" /etc/X11/xorg.conf.d/

# --- systemd units ---
install -m 0644 "${KIOSK_SYS}/services/kiosk.target" /etc/systemd/system/
install -m 0644 "${KIOSK_SYS}/services/kiosk-session.service" /etc/systemd/system/
systemctl daemon-reload
systemctl disable getty@tty1.service >/dev/null 2>&1 || true
systemctl enable kiosk.target kiosk-session.service >/dev/null
log "kiosk.target and kiosk-session.service enabled (start at next boot, or: systemctl start kiosk.target)"
