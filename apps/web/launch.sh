#!/usr/bin/env bash
# Starts Chrome in kiosk mode for app instance $1. Variables come from
# /opt/kiosk/state/apps/<name>.env (rendered by kioskctl apply):
#   APP_URL, APP_SCREEN (primary|all|OUTPUT), APP_GEOMETRY (fullscreen|WxH+X+Y), APP_EXTRA_FLAGS
# Global Chrome options come from /opt/kiosk/state/chrome.env (config: chrome.gpu, chrome.flags).
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
exec google-chrome-stable "${CHROME_ARGS[@]}" --window-position="${x},${y}" --window-size="${w},${h}" "${mode[@]}"
