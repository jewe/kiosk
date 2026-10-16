# autoinstall — unattended Ubuntu Server 24.04 install

1. Write the stock Ubuntu Server 24.04 ISO to USB stick 1 (balenaEtcher or `dd`).
2. Build stick 2: `./make-cidata.sh --hostname kiosk-01 --disk /dev/diskN` (or `--img out/cidata.img` for a VM).
3. Boot the PC from stick 1 with stick 2 plugged in. Confirm "Continue with autoinstall?" with one keypress.
4. After the reboot: `ssh kioskadmin@kiosk-01`, then `sudo /opt/kiosksystem/setup.sh`.

What the template does: SSH key-only admin user, `git` + `lvm2`, no snaps, GPT with BIOS+EFI boot, LVM with a 24G root and an 8G `kiosk-data` volume (`--root-size`, `--data-size`) at `/opt/kiosk` (rest of the disk stays free), clones this repo to `/opt/kiosksystem`, quiet boot.

`out/` is git-ignored because it contains the password hash and your public key.

The repo URL (`--repo`, default `https://github.com/jewe/kiosk.git`) must be reachable without credentials, i.e. public, or carry a read-only token (`https://TOKEN@github.com/...`). If the clone fails the install still completes and leaves `/root/KIOSK-CLONE-FAILED`; then run `bootstrap.sh` over SSH.
