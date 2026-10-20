# USB sticks

Two features: an automatic action when a stick is plugged in, and manual mounting for development. A third switch turns USB storage off entirely.

## Automatic action on plug-in

Enable in `kiosk.yaml`:

```yaml
services:
  usb_action:
    enabled: true
```

What happens after `sudo kioskctl apply`:

1. The udev rule `services/usb/90-kiosk-usb.rules` is installed. It fires when a partition on a USB block device appears and starts `kiosk-usb-action@<partition>.service`, for example `kiosk-usb-action@sda1`.
2. The unit runs `services/usb/handler.sh` as root. It checks the config flag again and mounts the partition at `/run/kiosk/usb/<partition>` with `noexec,nosuid,nodev`, so nothing on the stick can execute by itself.
3. It calls `/opt/kiosk/usb-action.sh <mountpoint> <device>`. This script is yours. On the first enable it is copied from `services/usb/usb-action.default.sh`; later applies leave it alone.
4. After the script returns, the stick is synced and unmounted. Pull it when the activity light stops.

Logs: `journalctl -t usb`, and `kioskctl status` shows whether the action is enabled.

### The default action

Writes `kiosk-<hostname>-<date>.txt` onto the stick with `kioskctl status` and the last 200 journal lines. Handy for a site visit without a laptop: plug in, wait a few seconds, pull.

### Writing your own action

The script runs as root with the stick mounted read/write. Examples:

```bash
#!/usr/bin/env bash
# copy new content from the stick into the data folder of the static app "menu"
mnt="$1"
if [ -d "$mnt/menu-data" ]; then
    rsync -a --delete "$mnt/menu-data/" /opt/kiosk/apps/menu/data/
    kioskctl app restart menu
fi
# collect screenshots and benchmark results
mkdir -p "$mnt/kiosk-$(hostname)"
cp -a /opt/kiosk/data/screenshots /opt/kiosk/data/bench "$mnt/kiosk-$(hostname)/" 2>/dev/null
```

Keep it short and non-interactive. Exit code and output go to the journal. The stick is mounted with `noexec`, so run scripts from the stick with an interpreter explicitly (`bash "$mnt/script.sh"`) and only if you trust whoever can plug in a stick.

Persistence: the script lives in `/opt/kiosk`, so it survives reboots in `rw`, `data` and `data+journal` mode. In `locked` mode it is reset to the default at every boot; keep your version in the repo or in `secrets/` and push it with `tools/secrets.sh` after switching to `data`.

## Manual mounting (development)

Always available, no config needed:

| Command | Effect |
|---|---|
| `sudo kioskctl usb list` | USB block devices with size, filesystem and label |
| `sudo kioskctl usb mount [dev]` | mounts the first USB partition (or `dev`) at `/media/usb`, owned by the kiosk user |
| `sudo kioskctl usb umount` | sync and unmount |
| `sudo kioskctl files` | caja on the kiosk screen with a visible cursor, drag files from the stick (needs `tools/install.sh mate`) |

## Turning USB storage off

```yaml
security:
  disable_usb_storage: true
```

Blacklists the `usb-storage` kernel module: sticks are not seen at all. Keyboards, mice and touchscreens are not affected. Refused while `usb_action` is enabled, the two cannot both be true. Takes effect at the next boot.

## Status

The automatic action is implemented and installed by apply, but not yet exercised with a real stick on kiosk-01.
