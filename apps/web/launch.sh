#!/usr/bin/env bash
# Starts Chrome in kiosk mode for app instance $1. Variables come from
# /opt/kiosk/state/apps/<name>.env (rendered by kioskctl apply):
#   APP_URL, APP_SCREEN (primary|all|OUTPUT), APP_GEOMETRY (fullscreen|WxH+X+Y), APP_EXTRA_FLAGS
set -euo pipefail
name="${1:?instance name}"
profile="${RUNTIME_DIRECTORY:-/run/kiosk/$name}"   # tmpfs: a fresh profile at every start

geom="${APP_GEOMETRY:-fullscreen}"
read -r w h x y < <(/opt/kiosksystem/display/place.sh geometry "${APP_SCREEN:-primary}" "$geom") || true
[ -n "${w:-}" ] || { w=1920; h=1080; x=0; y=0; }

# --kiosk always fills the whole monitor; a partial geometry uses app mode with a fixed window
if [ "$geom" = "fullscreen" ]; then
    mode=(--kiosk "${APP_URL:-about:blank}")
else
    mode=(--app="${APP_URL:-about:blank}")
fi
flags=(
    --user-data-dir="$profile"
    --window-position="${x},${y}"
    --window-size="${w},${h}"
    --no-first-run --no-default-browser-check
    --noerrdialogs --disable-infobars --disable-session-crashed-bubble
    --disable-features=TranslateUI
    --autoplay-policy=no-user-gesture-required
    --password-store=basic
    --check-for-update-interval=31536000
    --overscroll-history-navigation=0
    --disable-pinch
    --touch-events=enabled
    --enable-features=VaapiVideoDecodeLinuxGL
    --ignore-gpu-blocklist
    --class="kiosk-${name}"
)
# shellcheck disable=SC2206
[ -n "${APP_EXTRA_FLAGS:-}" ] && flags+=(${APP_EXTRA_FLAGS})

exec google-chrome-stable "${flags[@]}" "${mode[@]}"
