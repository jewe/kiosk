# Configuration reference: /opt/kiosk/config/kiosk.yaml

Apply with `sudo kioskctl apply`. Unknown keys are ignored. Everything has a default; the default file is `config/kiosk.default.yaml`.

| Key | Meaning |
|---|---|
| `device.id` | device name in status and heartbeat; empty = hostname |
| `display.background` | image for the root window and the boot splash |
| `display.outputs[]` | xrandr settings per output: `name`, `primary`, `mode`, `pos` (`XxY`), `rotate`, `rate`, `enabled`, `transform` (9 comma-separated matrix values). Empty list = `xrandr --auto` |
| `touch.output` | output name the touchscreen is mapped to |
| `audio.sink`, `audio.volume` | PipeWire default sink and volume in percent (planned) |
| `apps[]` | app instances: `name` ([a-z0-9_-]), `type`, `screen` (`primary`, `all`, output name), `geometry` (`fullscreen` or `WxH+X+Y` relative to the screen), plus type-specific keys. Every scalar key is passed to the app as `APP_<KEY>` |
| type `web` | `url`, `extra_flags` (Chrome flags) |
| type `video` | `path` (file, directory or URL), `loop` (true), `shuffle` (false), `audio` (true), `extra_flags` (mpv) |
| type `slideshow` | `path` (directory), `interval` (seconds per image, 10) |
| type `launcher` | `command` (run with bash -c), `wm_class` (optional, to find the window), `workdir` |
| type `static` | `path` (directory to serve) or `repo` + `branch` + `subdir` (git clone into `/opt/kiosk/apps/<name>/repo`), `update_on_boot`, `port` (127.0.0.1 only, default 8080), `extra_flags`. SPA fallback to index.html is on |
| `network.wifi[]` | up to three service WLAN names; credentials in `secrets/wifi.env` (planned) |
| `services.*` | each optional service with `enabled` and its settings (tunnel, app_update, usb_action, monitoring, scheduler) (planned) |
| `schedule` | per-weekday `on`/`off` times (planned) |
| `security.disable_usb_storage` | blacklist usb-storage (planned) |
| `persistence.mode` | `rw`, `locked`, `data`, `data+journal`; activated with `sudo kioskctl mount <mode>` + reboot |

Secrets are never in this file. They live in `/opt/kiosk/secrets/*.env` (root, 0600) and are referenced by name.
