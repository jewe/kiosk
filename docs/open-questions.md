# Open questions

Small items not yet decided. Each has a proposed default that will be used unless changed here.

| # | Question | Proposed default | Status |
|---|---|---|---|
| 1 | App rollback: keep a "last known good" copy of the app repo and switch with a symlink? | Not in the first version. Add when a bad update has actually happened once. | open |
| 2 | journald retention in `data+journal` mode | 90 days, 500 MB cap, `SyncIntervalSec=5min` | open |
| 3 | Stress-test pass criteria | implemented in tests/stress.sh: no app restarts, memory growth under 10 % first vs last quarter | done |
| 4 | Benchmark numbers that matter | glmark2 automated (`kioskctl bench gpu`); MotionMark only opened in Chrome, score read on screen. Automating it needs the DevTools protocol | partly |
| 5 | Heartbeat interval to the external receiver | 5 minutes, `services.monitoring.interval` | done |
| 6 | Device identity | hostname set during autoinstall, mirrored as `device.id` in kiosk.yaml | open |
| 7 | Which Chrome policies beyond extensions (no updates, no password manager, no first-run, no translate) | all of those on | open |
| 8 | USB-stick action: fixed script on the device, or script shipped on the stick? | Fixed script on the device (`/opt/kiosk/usb-action.sh`); default writes a status report to the stick | done |
| 9 | Scheduler off-action | `services.scheduler.off_action`: screen (default), apps, shutdown (rtcwake) | done |
| 10 | Verify on a device: `overlayroot-chroot <command>` runs the given command (used by `kioskctl mount` while locked) | if not, `kioskctl mount` must pipe a script into `overlayroot-chroot` | verify |
| 11 | Xorg under `PAMName=login` with `needs_root_rights=yes` | verified 2026-10-16 on kiosk-01 (Intel UHD 730, Ubuntu 26.04): boots to Chrome in 12 s | done |
| 12 | Verify on a device: persistence modes locked / data / data+journal (`kioskctl mount`), including the journal bind mount | run on kiosk-01 before the first production device | verify |
| 13 | Touch simulation: xdotool sends mouse events, not multitouch. Real touch events would need uinput (evemu/dotool) | mouse events are enough for browser apps | open |
