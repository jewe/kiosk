# server — heartbeat receiver

`heartbeat.php` is a single-file receiver: devices POST `{device, status, metrics}` with a bearer token, the page shows all devices in a table and marks the ones silent for more than 15 minutes.

Setup: copy to a PHP host, set `TOKEN`, make `data/` writable by the web server. On the kiosk: `services.monitoring: {enabled: true, url: https://host/heartbeat.php, interval: 5m}` and `MONITORING_TOKEN` in `/opt/kiosk/secrets/monitoring.env`.

Alternative without code: Uptime Kuma's push monitor, using its push URL as `services.monitoring.url` (no token).
