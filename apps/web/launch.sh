#!/usr/bin/env bash
# Starts Chrome (or Chromium, chrome.browser) in kiosk mode for app instance $1. Variables come from
# /opt/kiosk/state/apps/<name>.env (rendered by kioskctl apply):
#   APP_URL, APP_SCREEN (primary|all|OUTPUT), APP_GEOMETRY (fullscreen|WxH+X+Y), APP_EXTRA_FLAGS
# Global Chrome options come from /opt/kiosk/state/chrome.env (config: chrome.gpu, chrome.flags, chrome.cache_size).
set -euo pipefail
name="${1:?instance name}"
profile="${RUNTIME_DIRECTORY:-/run/kiosk/$name}"   # tmpfs: a fresh profile at every start
source /opt/kiosksystem/apps/web/chrome-flags.sh

geom="${APP_GEOMETRY:-fullscreen}"
read -r w h x y < <(/opt/kiosksystem/display/place.sh geometry "${APP_SCREEN:-primary}" "$geom") || true
[ -n "${w:-}" ] || { w=1920; h=1080; x=0; y=0; }

# --kiosk always fills the whole monitor; a partial geometry uses app mode with a fixed window
if [ "$geom" = "fullscreen" ]; then
    mode=(--kiosk "${APP_URL:-about:blank}")
else
    mode=(--app="${APP_URL:-about:blank}")
fi

# compiled shaders from the last run, so the first seconds are not spent compiling
/opt/kiosksystem/apps/web/shader-cache.sh restore "$name" "$profile" || true

chrome_flags "$name" "$profile"
# chrome.cache_size (CHROME_CACHE_BYTES from chrome.env): the HTTP cache lives on the data volume instead of
# the tmpfs profile, so videos and images survive restarts and reboots and do not take RAM. Skipped where
# that folder is in RAM anyway (persistence locked overlays /opt/kiosk). At most half the free space.
cache="/opt/kiosk/cache/$name"
if [ "${CHROME_CACHE_BYTES:-0}" -gt 0 ] && mkdir -p "$cache" 2>/dev/null; then
    case "$(stat -f -c %T "$cache")" in
        tmpfs|overlayfs|ramfs) ;;
        *)  used="$(du -sb "$cache" | cut -f1)"; avail="$(df -B1 --output=avail "$cache" | tail -1)"
            size=$(( (avail + used) / 2 )); [ "$size" -le "$CHROME_CACHE_BYTES" ] || size="$CHROME_CACHE_BYTES"
            CHROME_ARGS+=(--disk-cache-dir="$cache" --disk-cache-size="$size") ;;
    esac
fi
# CHROME_BROWSER comes from /opt/kiosk/state/chrome.env (config: chrome.browser), sourced by chrome_flags
bin=google-chrome-stable; [ "${CHROME_BROWSER:-chrome}" = chromium ] && bin=chromium
exec "$bin" "${CHROME_ARGS[@]}" --window-position="${x},${y}" --window-size="${w},${h}" "${mode[@]}"
