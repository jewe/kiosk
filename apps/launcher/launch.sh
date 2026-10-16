#!/usr/bin/env bash
# Runs APP_COMMAND (through bash -c) and places its first window.
# Env: APP_COMMAND, APP_WM_CLASS (optional, to find the window), APP_SCREEN, APP_GEOMETRY, APP_WORKDIR
set -uo pipefail
name="${1:?instance name}"
[ -n "${APP_COMMAND:-}" ] || { echo "app '$name': command is required" >&2; sleep 10; exit 1; }
cd "${APP_WORKDIR:-/opt/kiosk/apps/$name}" 2>/dev/null || cd /

bash -c "$APP_COMMAND" &
pid=$!
# place the window in the background; the app keeps running even when no window is found
( /opt/kiosksystem/display/place.sh window "$pid" "${APP_WM_CLASS:-}" "${APP_SCREEN:-primary}" "${APP_GEOMETRY:-fullscreen}" \
    || echo "app '$name': window not found, not placed" >&2 ) &
wait "$pid"
