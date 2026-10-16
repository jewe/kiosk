# services — systemd units and udev rules

- `kiosk.target`: groups the session and all app instances. `systemctl enable kiosk.target` makes the kiosk start at boot.
- `kiosk-session.service`: Xorg + openbox on tty1 as user `kiosk`, no display manager.
- App units live next to their type in `apps/<type>/kiosk-<type>@.service` and are installed by that type's `install.sh`.
- Later: tunnel, app-update, usb-action, monitor timer, scheduler timers.
