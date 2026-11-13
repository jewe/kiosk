#!/usr/bin/env bash
# The browser behind every web/static app: chrome.browser in kiosk.yaml, chrome (default) or chromium.
#   browser.sh ensure     install the configured browser if it is missing, install the hardening policies
#                         into its policy directory, drop kiosk policies from the other browser's directory
#   browser.sh info       which browser, binary, version, policy directory
# Both are debs, never snaps. Chrome comes from Google; Chromium from the xtradeb PPA, because Ubuntu's own
# chromium package is only a snap wrapper. Neither is upgraded unattended (services/updates).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="browser"
cmd="${1:-info}"

installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; }

install_chrome() {
    installed google-chrome-stable && return 0
    apt_update_once
    apt_install wget gnupg ca-certificates
    local tmp; tmp="$(mktemp -d)"
    wget -qO "$tmp/chrome.deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt-get install -y "$tmp/chrome.deb"
    rm -rf "$tmp"
    # Chrome adds its own apt repo; updates only happen via `kioskctl update`.
}

install_chromium() {
    installed chromium && return 0
    # Ubuntu's "chromium-browser" is a transitional package that pulls in snapd; the kiosk has no snaps.
    apt_install software-properties-common ca-certificates
    if ! grep -rqs "xtradeb/apps" /etc/apt/sources.list.d/; then
        log "adding the xtradeb PPA (Chromium as a deb)"
        add-apt-repository -y ppa:xtradeb/apps
    fi
    apt-get update
    apt_install chromium
    installed chromium || die "chromium could not be installed from ppa:xtradeb/apps (no package for this Ubuntu release?)"
}

ensure() {
    require_root
    local b other dir odir
    b="$(kiosk_browser)"; [ "$b" = chromium ] && other=chrome || other=chromium
    if [ "$b" = chromium ]; then install_chromium; else install_chrome; fi
    dir="$(browser_policy_dir "$b")"; odir="$(browser_policy_dir "$other")"
    install -d -m 0755 "$dir"
    install -m 0644 "${KIOSK_SYS}/apps/web/policies.json" "$dir/kiosk.json"
    # the other browser stays installed (switching back needs no download) but loses the kiosk policies,
    # so a stale forced-extension list cannot outlive the switch
    rm -f "$odir/kiosk.json" "$odir/kiosk-extensions.json"
    command -v "$(browser_bin "$b")" >/dev/null || die "$(browser_bin "$b") not found after install"
}

case "$cmd" in
    ensure) ensure ;;
    info)   printf 'browser: %s\nbinary:  %s\nversion: %s\npolicy:  %s\n' "$(kiosk_browser)" "$(command -v "$(browser_bin)" || echo "not installed")" "$(browser_version)" "$(browser_policy_dir)" ;;
    *)      sed -n '2,7p' "$0"; exit 2 ;;
esac
