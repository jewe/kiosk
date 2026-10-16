# Open questions

Small items not yet decided. Each has a proposed default that will be used unless changed here.

| # | Question | Proposed default | Status |
|---|---|---|---|
| 1 | App rollback: keep a "last known good" copy of the app repo and switch with a symlink? | Not in the first version. Add when a bad update has actually happened once. | open |
| 2 | journald retention in `data+journal` mode | 90 days, 500 MB cap, `SyncIntervalSec=5min` | open |
| 3 | Stress-test pass criteria | No app restarts during the run, resident memory growth under 10 % between hour 1 and the end | open |
| 4 | Benchmark numbers that matter | MotionMark score and glmark2 score, stored per run; no threshold | open |
| 5 | Heartbeat interval to the external receiver | 5 minutes | open |
| 6 | Device identity | hostname set during autoinstall, mirrored as `device.id` in kiosk.yaml | open |
| 7 | Which Chrome policies beyond extensions (no updates, no password manager, no first-run, no translate) | all of those on | open |
| 8 | USB-stick action: fixed script on the device, or script shipped on the stick? | Fixed script on the device (`/opt/kiosk/usb-action.sh`); the stick only carries data | open |
| 9 | Scheduler off-action: screens off via DPMS, or full shutdown with rtcwake? | DPMS first; rtcwake as opt-in | open |
| 10 | Verify on a device: `overlayroot-chroot <command>` runs the given command (used by `kioskctl mount` while locked) | if not, `kioskctl mount` must pipe a script into `overlayroot-chroot` | verify |
| 11 | Xorg under `PAMName=login` with `needs_root_rights=yes` | verified 2026-10-16 on kiosk-01 (Intel UHD 730, Ubuntu 26.04): boots to Chrome in 12 s | done |
