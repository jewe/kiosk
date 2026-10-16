# apps — one directory per app type

Each type ships `install.sh` (packages + unit), `launch.sh` (started by the unit) and `kiosk-<type>@.service` (template unit, one instance per app in `kiosk.yaml`). Instances get their settings from `/opt/kiosk/state/apps/<name>.env`, rendered by `kioskctl apply`. Optional hooks per type: `render.sh <name>` (after the env file is written), `remove.sh <name>` (instance removed from config), `update.sh <name>` (`kioskctl app update`).

| Type | Status |
|---|---|
| `web` | Chrome kiosk, window placed on `screen` with `geometry` |
| `static` | nginx on 127.0.0.1 serving a directory or a git repo (Nuxt build), shown by Chrome; `kioskctl app update <name>` pulls |
| `video` | mpv: file, directory (playlist) or URL, loop, hw decode; keys `path`, `loop`, `shuffle`, `audio`, `extra_flags` |
| `slideshow` | mpv image loop from a directory; keys `path`, `interval` (s) |
| `launcher` | any `command` (bash -c), window found by `wm_class` or pid and placed; `workdir` |
