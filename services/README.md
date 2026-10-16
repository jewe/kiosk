# services — systemd units and udev rules

- `kiosk.target`: groups the session and all app instances. `systemctl enable kiosk.target` makes the kiosk start at boot.
- `kiosk-session.service`: Xorg + openbox on tty1 as user `kiosk`, no display manager.
- App units live next to their type in `apps/<type>/kiosk-<type>@.service` and are installed by that type's `install.sh`.
- `tunnel/`: autossh reverse tunnel (`services.tunnel`), key pair generated into `/opt/kiosk/secrets/tunnel/` on first apply.
- `wifi/`: NetworkManager profiles for up to 3 service WLANs (`network.wifi`, credentials in `secrets/wifi.env`).
- `usb/`: udev rule + unit running `/opt/kiosk/usb-action.sh <mountpoint> <device>` when a stick is plugged in (`services.usb_action`). Default action writes a status report to the stick.
- `audio/`: default sink and volume via wpctl (`audio`), applied at every session start.
- `security/`: usb-storage blacklist (`security.disable_usb_storage`).
- `scheduler/`: `schedule` → systemd timers `kiosk-schedule-on/off`, actions screen/apps/shutdown, state sync after boot.
- Each has an `apply.sh` run by `kioskctl apply`.
