# apps — one directory per app type

Each type ships `install.sh` (packages + unit), `launch.sh` (started by the unit) and `kiosk-<type>@.service` (template unit, one instance per app in `kiosk.yaml`). Instances get their settings from `/opt/kiosk/state/apps/<name>.env`, rendered by `kioskctl apply`.

| Type | Status |
|---|---|
| `web` | Chrome kiosk, window placed on `screen` with `geometry` |
| `nuxt-static` | planned: nginx + web instance |
| `video` | planned: mpv loop |
| `slideshow` | planned |
| `launcher` | planned: any command + geometry |
