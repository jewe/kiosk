#!/usr/bin/env bash
# mpv in a borderless window placed on the configured screen/geometry.
# Env: APP_PATH (file, directory or URL), APP_LOOP (true), APP_SHUFFLE (false), APP_AUDIO (true),
#      APP_INTERVAL (seconds per image, slideshow), APP_EXTRA_FLAGS, APP_SCREEN, APP_GEOMETRY
set -euo pipefail
name="${1:?instance name}"
[ -n "${APP_PATH:-}" ] || { echo "app '$name': path is required" >&2; sleep 10; exit 1; }

read -r w h x y < <(/opt/kiosksystem/display/place.sh geometry "${APP_SCREEN:-primary}" "${APP_GEOMETRY:-fullscreen}") || true
[ -n "${w:-}" ] || { w=1920; h=1080; x=0; y=0; }

flags=(
    --no-terminal --really-quiet --no-osc --no-osd-bar --osd-level=0
    --no-input-default-bindings --input-conf=/dev/null --no-input-cursor --cursor-autohide=always
    --force-window=immediate --no-border --no-keepaspect-window --geometry="${w}x${h}+${x}+${y}"
    --hwdec=auto-safe --vo=gpu --profile=fast
    --background=color --background-color=0/0/0
    --config-dir="${RUNTIME_DIRECTORY:-/run/kiosk/$name}"
)
[ "${APP_LOOP:-true}" = "false" ]    || flags+=(--loop-playlist=inf)
[ "${APP_SHUFFLE:-false}" = "true" ] && flags+=(--shuffle)
[ "${APP_AUDIO:-true}" = "false" ]   && flags+=(--no-audio)
[ -n "${APP_INTERVAL:-}" ]           && flags+=(--image-display-duration="${APP_INTERVAL}")
# shellcheck disable=SC2206
[ -n "${APP_EXTRA_FLAGS:-}" ] && flags+=(${APP_EXTRA_FLAGS})

exec mpv "${flags[@]}" -- "$APP_PATH"
