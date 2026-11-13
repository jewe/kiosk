#!/usr/bin/env bash
# The browser behind every web/static app: chrome.browser in kiosk.yaml, chrome (default) or chromium.
#   browser.sh ensure     install the configured browser if it is missing, install the hardening policies
#                         into its policy directory, drop kiosk policies from the other browser's directory
#   browser.sh info       which browser, binary, version, policy directory
#   browser.sh urls       write (or remove) the domain allowlist policy kiosk-urls.json (chrome.allowed_domains)
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

# chrome.allowed_domains: when the list is not empty, every URL is blocked except these (policies URLBlocklist
# ["*"] + URLAllowlist). Entries use Chrome's URL filter format: "example.com" = the host and all subdomains,
# ".example.com" = exactly this host, "example.com/path", "https://example.com:8443". Always allowed: the local
# servers (static apps, extensions on 127.0.0.1) and the host of every web app's url. A blocked link shows
# Chrome's "blocked by your administrator" page. Own file, so `bench.sh` can lift it for a run.
url_policy() {
    local dir="$1" pol="$1/kiosk-urls.json" n
    n="$(cfg '.chrome.allowed_domains // [] | length' 0)"
    if [ "$n" -eq 0 ]; then
        [ -f "$pol" ] && rm -f "$pol" && log "chrome.allowed_domains empty: URL restriction removed"
        return 0
    fi
    yq '{URLBlocklist: ["*"],
         URLAllowlist: ([(.chrome.allowed_domains // [])[] | tostring | select(length > 0)]
             + ["127.0.0.1", "localhost", "about:blank"]
             + [(.apps // [])[] | select(.type == "web") | .url // empty | tostring
                | capture("^(?<p>[a-z]+://[^/?#]+)") | .p]
           | unique)}' "$KIOSK_CONFIG" | write_file "$pol" 0644 \
        && log "URL restriction written: $n allowed domain(s)" || true
}

ensure() {
    require_root
    local b other dir odir
    b="$(kiosk_browser)"; [ "$b" = chromium ] && other=chrome || other=chromium
    if [ "$b" = chromium ]; then install_chromium; else install_chrome; fi
    dir="$(browser_policy_dir "$b")"; odir="$(browser_policy_dir "$other")"
    install -d -m 0755 "$dir"
    install -m 0644 "${KIOSK_SYS}/apps/web/policies.json" "$dir/kiosk.json"
    url_policy "$dir"
    # the other browser stays installed (switching back needs no download) but loses the kiosk policies,
    # so a stale forced-extension list cannot outlive the switch
    rm -f "$odir/kiosk.json" "$odir/kiosk-extensions.json" "$odir/kiosk-urls.json"
    command -v "$(browser_bin "$b")" >/dev/null || die "$(browser_bin "$b") not found after install"
}

case "$cmd" in
    ensure) ensure ;;
    urls)   require_root; install -d -m 0755 "$(browser_policy_dir)"; url_policy "$(browser_policy_dir)" ;;
    info)   printf 'browser: %s\nbinary:  %s\nversion: %s\npolicy:  %s\n' "$(kiosk_browser)" "$(command -v "$(browser_bin)" || echo "not installed")" "$(browser_version)" "$(browser_policy_dir)" ;;
    *)      sed -n '2,8p' "$0"; exit 2 ;;
esac
