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

/opt/kiosksystem/services/audio/apply.sh || true

# pointer hidden in production; visible in dev mode (kioskctl devmode on / kioskctl cursor show)
[ -f "${KIOSK_STATE}/devmode" ] || unclutter-xfixes --start-hidden --hide-on-touch --timeout 1 --fork >/dev/null 2>&1 || true

# openbox reads its config through a symlink so `kioskctl devmode` can switch it and reconfigure in place
rc=/opt/kiosksystem/display/openbox/rc.xml
[ -f "${KIOSK_STATE}/devmode" ] && rc=/opt/kiosksystem/display/openbox/rc-dev.xml && log "dev mode: escape hotkeys active"
ln -sfn "$rc" "${KIOSK_STATE}/openbox-rc.xml"
exec openbox --config-file "${KIOSK_STATE}/openbox-rc.xml"
