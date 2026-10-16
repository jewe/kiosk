# Configuration reference: /opt/kiosk/config/kiosk.yaml

Apply with `sudo kioskctl apply`. Unknown keys are ignored. Everything has a default; the default file is `config/kiosk.default.yaml`.

| Key | Meaning |
|---|---|
| `device.id` | device name in status and heartbeat; empty = hostname |
| `display.background` | image for the root window and the boot splash |
| `display.outputs[]` | xrandr settings per output: `name`, `primary`, `mode`, `pos` (`XxY`), `rotate`, `rate`, `enabled`, `transform` (9 comma-separated matrix values). Empty list = `xrandr --auto` |
| `touch.output` | output name the touchscreen is mapped to |
| `audio.sink`, `audio.volume` | PipeWire default sink (substring of the sink name in `wpctl status`) and volume in percent |
| `apps[]` | app instances: `name` ([a-z0-9_-]), `type`, `screen` (`primary`, `all`, output name), `geometry` (`fullscreen` or `WxH+X+Y` relative to the screen), plus type-specific keys. Every scalar key is passed to the app as `APP_<KEY>` |
| type `web` | `url`, `extra_flags` (Chrome flags) |
| type `video` | `path` (file, directory or URL), `loop` (true), `shuffle` (false), `audio` (true), `extra_flags` (mpv) |
| type `slideshow` | `path` (directory), `interval` (seconds per image, 10) |
| type `launcher` | `command` (run with bash -c), `wm_class` (optional, to find the window), `workdir` |
| type `static` | `path` (directory to serve) or `repo` + `branch` + `subdir` (app build, cloned to `/opt/kiosk/apps/<name>/repo`); optional `data_repo` + `data_branch` + `data_subdir` served under `data_url` (`/data`) with `Cache-Control: no-cache`; `update_on_boot`, `update_interval` (0 = off), `on_app_change` (restart), `on_data_change` (reload); `port` (127.0.0.1 only, 8080), `extra_flags`. SPA fallback to index.html is on. Private repos use per-repo deploy keys from `kioskctl secrets git-key <name>-app` / `<name>-data` (fallback: the unlabelled key). See `docs/nuxt-app.md` |
| `network.wifi[]` | up to three service WLAN names in priority order; `WIFI_<NAME>_SSID` / `WIFI_<NAME>_PSK` in `secrets/wifi.env` |
| `services.tunnel` | `enabled`, `host`, `port` (22), `user` (tunnel), `remote_port` (20022). Key in `secrets/tunnel/`, public key printed by apply |
| `services.usb_action` | `enabled`; action script `/opt/kiosk/usb-action.sh` |
| `services.monitoring` | `enabled` (heartbeat), `url`, `interval` (5m, also the local metrics interval). Token in `secrets/monitoring.env` |
| `services.scheduler` | `enabled`, `off_action`: `screen` (DPMS off, default), `apps` (stop all app units), `shutdown` (poweroff, wake via rtcwake at the next on time) |
| `schedule` | map of day → `{on: "HH:MM", off: "HH:MM"}`; days `mon`…`sun`, ranges `mon-fri`, or `daily`. After boot the current state is applied |
| `security.disable_usb_storage` | blacklist usb-storage; refused while `usb_action` is enabled |
| `persistence.mode` | `rw`, `locked`, `data`, `data+journal`; activated with `sudo kioskctl mount <mode>` + reboot |

Secrets are never in this file. They live in `/opt/kiosk/secrets/*.env` (root, 0600) and are referenced by name.
