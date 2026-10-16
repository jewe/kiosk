#!/usr/bin/env bash
# Starts Chrome in kiosk mode for app instance $1. Variables come from
# /opt/kiosk/state/apps/<name>.env (rendered by kioskctl apply):
#   APP_URL, APP_SCREEN (primary|all|OUTPUT), APP_GEOMETRY (fullscreen|WxH+X+Y), APP_EXTRA_FLAGS
set -euo pipefail
name="${1:?instance name}"
profile="${RUNTIME_DIRECTORY:-/run/kiosk/$name}"   # tmpfs: a fresh profile at every start

w=""; h=""; x=0; y=0
read -r w h x y < <(/opt/kiosksystem/display/screen-geometry.sh "${APP_SCREEN:-primary}") || true
if [ -z "$w" ] || [ -z "$h" ]; then
    echo "screen '${APP_SCREEN:-primary}' not found, falling back to 1920x1080+0+0" >&2
    w=1920; h=1080; x=0; y=0
fi

geom="${APP_GEOMETRY:-fullscreen}"
if [ "$geom" != "fullscreen" ] && [[ "$geom" =~ ^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$ ]]; then
    w="${BASH_REMATCH[1]}"; h="${BASH_REMATCH[2]}"
    x=$(( x + BASH_REMATCH[3] )); y=$(( y + BASH_REMATCH[4] ))
fi

flags=(
    --kiosk
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

exec google-chrome-stable "${flags[@]}" "${APP_URL:-about:blank}"
