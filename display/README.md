# display — Xorg + openbox session, drivers, screen and touch config

- `install.sh` installs Xorg, openbox, detects the GPU and drops the matching tearing config into `/etc/X11/xorg.conf.d/`, installs the session units.
- `xsession.sh` is the X client started by `startx` from `kiosk-session.service`: screen saver off, screens from config, background, openbox.
- `apply-display.sh` turns `display.outputs` and `touch.output` from `kiosk.yaml` into xrandr/xinput calls. Re-run at any time with `kioskctl apply`.
- `screen-geometry.sh <primary|all|OUTPUT>` prints `W H X Y`; used by app launchers to place windows.
- `wait-for-x.sh` is the `ExecStartPre` of every app unit.
