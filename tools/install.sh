#!/usr/bin/env bash
# Optional developer tools, chosen with checkboxes (whiptail). Re-runnable.
#   sudo tools/install.sh            interactive
#   sudo tools/install.sh node vscode mate htop devmode    non-interactive
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="tools"
require_root

if [ $# -gt 0 ]; then
    choice="$*"
else
    apt_install whiptail
    choice="$(whiptail --title "Kiosk dev tools" --checklist "Select what to install (space toggles)" 18 70 8 \
        node    "Node.js LTS (nodesource)"                       off \
        vscode  "Visual Studio Code (Microsoft repo)"            off \
        mate    "MATE helpers: caja, mate-terminal, pluma"       off \
        htop    "htop, nvtop, iotop, ncdu"                       on  \
        devmode "Escape hotkeys in the kiosk session (Ctrl+Alt+T terminal)" on \
        glmark2 "glmark2 GPU benchmark"                          off \
        3>&1 1>&2 2>&3)" || exit 0
    choice="${choice//\"/}"
fi
apt_update_once
for item in $choice; do
    case "$item" in
        node)
            if ! command -v node >/dev/null; then
                curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >/dev/null
                apt_install nodejs
            fi; log "node $(node -v)" ;;
        vscode)
            if ! command -v code >/dev/null; then
                curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
                echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
                apt-get update; apt_install code
            fi; log "vscode installed" ;;
        mate)   apt_install caja mate-terminal pluma udisks2 gvfs gvfs-backends gvfs-fuse mate-polkit eom; log "mate helpers installed (part of the base setup since 0.2.63; caja mounts USB sticks via udisks2)" ;;
        htop)   apt_install htop nvtop iotop ncdu; log "monitoring tools installed" ;;
        glmark2) apt_install glmark2 ;;
        devmode) kioskctl devmode on ;;
        *) warn "unknown item $item" ;;
    esac
done
log "done"
