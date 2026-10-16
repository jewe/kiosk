#!/usr/bin/env bash
# Step 0 on a manually installed Ubuntu Server: install git + openssh, clone the repo.
# Not needed when the OS was installed with autoinstall/ (the installer clones already).
#
#   curl -fsSL https://raw.githubusercontent.com/<org>/kiosk/main/bootstrap.sh | sudo bash
#   KIOSK_REPO=https://github.com/<org>/kiosk.git sudo -E bash bootstrap.sh

set -euo pipefail
KIOSK_REPO="${KIOSK_REPO:-https://github.com/jewe/kiosk.git}"
KIOSK_SYS="${KIOSK_SYS:-/opt/kiosksystem}"

[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends git openssh-server ca-certificates curl
systemctl enable --now ssh

if [ -d "${KIOSK_SYS}/.git" ]; then
    echo "repo already present at ${KIOSK_SYS}, pulling"
    git -C "${KIOSK_SYS}" pull --ff-only
else
    git clone "${KIOSK_REPO}" "${KIOSK_SYS}"
fi

echo
echo "bootstrap done. Connect via SSH and run:"
echo "  sudo ${KIOSK_SYS}/setup.sh"
ip -4 -o addr show scope global | awk '{print "  " $2 ": " $4}'
