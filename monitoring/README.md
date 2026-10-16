# monitoring — metrics into journald, heartbeat push

- `collect.sh [--log]`: one JSON line (temps, fan, throttling, load, memory, disks, uptime, app restarts), logged under tag `kiosk-monitor`.
- `heartbeat.sh`: POSTs status + metrics to `services.monitoring.url` with the token from `secrets/monitoring.env`.
- `kiosk-monitor.timer`: runs both every `services.monitoring.interval` (default 5m). Metrics always, heartbeat only when enabled.
- `kioskctl history [N]` reads the journal back; `journalctl -t kiosk-monitor -o cat` exports raw JSON.
