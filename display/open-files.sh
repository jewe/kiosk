#!/usr/bin/env bash
# Dev hotkey Ctrl+Alt+F: file manager on the kiosk screen with a visible cursor. Runs as the kiosk user
# from openbox (display/openbox/rc-dev.xml). Same launch as `kioskctl files`, without root.
dir="${1:-/opt/kiosk}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
pkill -f '^unclutter-xfixes' 2>/dev/null || true
xsetroot -cursor_name left_ptr 2>/dev/null || true
exec setsid caja --no-desktop "$dir" > /tmp/kiosk-caja.log 2>&1 < /dev/null
