#!/usr/bin/env bash
# Runs inside the X server started by kiosk-session.service (via startx).
# Configures screens from kiosk.yaml, sets the background, then runs openbox.
source /opt/kiosksystem/lib/common.sh
LOG_TAG="xsession"

xset s off
xset s noblank
xset -dpms
xsetroot -cursor_name left_ptr -solid black

/opt/kiosksystem/display/apply-display.sh || warn "display apply failed, continuing with defaults"

bg="$(cfg '.display.background' '')"
[ -n "$bg" ] && [ -f "$bg" ] && feh --no-fehbg --bg-fill "$bg" || true

unclutter-xfixes --start-hidden --hide-on-touch --timeout 1 --fork >/dev/null 2>&1 || true

exec openbox --config-file /opt/kiosksystem/display/openbox/rc.xml
