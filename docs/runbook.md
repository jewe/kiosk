# Runbook

## First device, step by step

1. One stick: `autoinstall/make-iso.sh --iso <ubuntu-server.iso> --hostname kiosk-01`, write the ISO to a stick. (Alternative: stock ISO on stick 1 plus `make-cidata.sh --disk /dev/diskN` on stick 2, then one keypress to confirm.)
2. Boot the PC from the stick, wait for the reboot, remove the stick.
3. `ssh kioskadmin@kiosk-01` (SSH key only). `sudo /opt/kiosksystem/setup.sh` (5 to 10 minutes, installs the display stack and drivers).
4. `sudo /opt/kiosksystem/apps/web/install.sh`.
5. `sudo nano /opt/kiosk/config/kiosk.yaml`: set the URL, screens, touch output. `sudo kioskctl apply`.
6. `sudo reboot`. The kiosk comes up on tty1 with Chrome fullscreen.
7. `kioskctl status`, `kioskctl doctor`.
8. Going to production: `sudo kioskctl mount locked` (or `data`, `data+journal`) and reboot.

## Manual install without autoinstall

Install Ubuntu Server normally (choose LVM, do not use the whole disk for root). Then:

```sh
curl -fsSL https://raw.githubusercontent.com/jewe/kiosk/main/bootstrap.sh | sudo bash
sudo /opt/kiosksystem/setup.sh
sudo kioskctl storage init      # creates the kiosk-data LV from free VG space
```

## Testing in a VM on the Mac (UTM)

- New VM, Linux, boot ISO = Ubuntu Server 24.04, add a second drive from `autoinstall/out/cidata.img` built with `--img`.
- Display: virtio-gpu, 2 displays if multiscreen is to be tested. GPU detection falls back to modesetting.
- Chrome needs about 4 GB RAM in the VM.

## Daily operations

| Task | Command |
|---|---|
| summary | `kioskctl status` / `kioskctl status --json` |
| self-test | `kioskctl doctor` |
| change config | edit `/opt/kiosk/config/kiosk.yaml`, `sudo kioskctl apply` |
| restart an app | `sudo kioskctl app restart main` |
| app log | `kioskctl app logs main` |
| session log | `journalctl -u kiosk-session -b` |
| re-apply screens live | `sudo kioskctl display` |
| unlock for changes | `sudo kioskctl mount rw`, reboot; afterwards `sudo kioskctl mount locked`, reboot |
| small change while locked | `sudo mount -o remount,rw /run/rootfsbase && sudo chroot /run/rootfsbase`, edit, exit, `sudo mount -o remount,ro /run/rootfsbase` |
| update system scripts | `sudo kioskctl update` (needs rw) |
| screenshot | `sudo kioskctl screenshot` (file) or `sudo kioskctl screenshot --telegram` |
| copy files from a USB stick | `sudo kioskctl usb mount`, copy from `/media/usb`, `sudo kioskctl usb umount`; or on screen `sudo kioskctl files` (caja, after `tools/install.sh mate`) |
| release a version | patch bumps with every commit (hook); `tools/release.sh minor` on the Mac for a minor release, then `sudo kioskctl update` on the devices |

## Troubleshooting

- Screen frozen, screenshots fail, new windows never appear: a text console is active (someone pressed Ctrl+Alt+F2). `sudo kioskctl display` or `sudo chvt 1` switches back; `kioskctl doctor` reports it.
- Black screen, no Chrome: `journalctl -u kiosk-session -b`, then `journalctl -u 'kiosk-web@*' -b`.
- Xorg does not start as user kiosk: check `/etc/X11/Xwrapper.config` has `allowed_users=anybody`, and the kiosk user is in `video`, `input`, `tty`.
- nvidia: `nvidia-smi`, and `/var/log/Xorg.0.log` for the composition pipeline line. `ubuntu-drivers devices` lists the recommended driver.
- Touch mapped to the wrong screen: `DISPLAY=:0 xinput list`, set `touch.output` in the config, `sudo kioskctl display`.
- On-site keyboard: Ctrl+Alt+F2 gives a text console (login as kioskadmin). Ctrl+Alt+Backspace is disabled.
