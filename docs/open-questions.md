# Open questions

Small items. Mark a row `ok` to accept the proposed default; it is then implemented and set to `done`.

| # | Question | Proposed default | Status |
|---|---|---|---|
| 1 | App rollback: keep a "last known good" copy of the app repo and switch with a symlink? | accepted: not in the first version, add when a bad update has actually happened once | done |
| 2 | journald retention in `data+journal` mode | accepted and implemented in core/06_persistence.sh: 90 days, 500 MB cap, `SyncIntervalSec=5min` | done |
| 3 | Stress-test pass criteria | implemented in tests/stress.sh: no app restarts, memory growth under 10 % first vs last quarter | done |
| 4 | Benchmark numbers that matter | glmark2 and MotionMark automated (`kioskctl bench gpu|motionmark|ab`), MotionMark score via DevTools (`tests/cdp.py`), see `docs/performance.md`. MotionMark run on kiosk-01 still pending (device was offline) | done |
| 5 | Heartbeat interval to the external receiver | 5 minutes, `services.monitoring.interval` | done |
| 6 | Device identity | hostname set during autoinstall; `device.id` empty = hostname (implemented) | done |
| 7 | Which Chrome policies beyond extensions (no updates, no password manager, no first-run, no translate) | all of those on, in apps/web/policies.json | done |
| 8 | USB-stick action: fixed script on the device, or script shipped on the stick? | Fixed script on the device (`/opt/kiosk/usb-action.sh`); default writes a status report to the stick | done |
| 9 | Scheduler off-action | `services.scheduler.off_action`: screen (default), apps, shutdown (rtcwake) | done |
| 10 | overlayroot on dracut-based Ubuntu | `/etc/overlayroot.conf` is ignored; kioskctl uses `rd.overlay` on the kernel command line and its own chroot into `/run/rootfsbase` | done |
| 11 | Xorg under `PAMName=login` with `needs_root_rights=yes` | verified 2026-10-16 on kiosk-01 (Intel UHD 730, Ubuntu 26.04): boots to Chrome in 12 s | done |
| 12 | Persistence modes on a device | verified 2026-10-16 on kiosk-01: data, data+journal (journal survives reboots), locked (root and /opt/kiosk volatile), rw; switching from inside an active overlay works | done |
| 13 | Touch simulation: xdotool sends mouse events, not multitouch. Real touch events would need uinput (evemu/dotool) | mouse events are enough for browser apps | open |
| 14 | Two-repo static app against private GitHub repos | verified 2026-10-16 on kiosk-01 with jewe/kiosk-test-app and jewe/kiosk-test-data, one deploy key per repo, data change reloaded the page | done |
| 15 | External monitoring server: build our own or use an existing project? | Current state: `server/heartbeat.php` keeps the last status per device and shows a table, no history, no alerts. Candidates (all Docker on an own server, all push-capable so NAT is no problem): **Uptime Kuma** for up/down, alerts and a status page via a push URL called from the heartbeat (no custom server code, but it stores no temperature/memory history); **Beszel** for hardware history charts, its agent opens a WebSocket to the hub (needs a `services/beszel` entry on the kiosk, does not know app state or persistence); **Grafana + VictoriaMetrics** as one stack for everything, the heartbeat would push Prometheus-format metrics, dashboards and alert rules to be built. Recommendation: Uptime Kuma plus Beszel, with the kiosk details (apps, version, persistence) in the Kuma push message; keep the PHP file as the no-infrastructure fallback. Kiosk side for each: `services.monitoring.kuma_url` in heartbeat.sh (about 10 lines); a Beszel agent service with hub URL and token in secrets; a collect.sh → Prometheus text converter | open |
