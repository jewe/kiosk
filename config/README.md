# config — default `kiosk.yaml` and templates

`kiosk.default.yaml` is copied to `/opt/kiosk/config/kiosk.yaml` on first setup. `kioskctl apply` validates the file and renders app env files, display settings and the persistence mode from it. See `docs/config.md`.
