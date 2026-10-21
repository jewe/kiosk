# Kiosk

Scripts and documentation to turn a bare x86 PC into a long-running Linux kiosk: Ubuntu Server LTS (tested with 26.04.1, written for 24.04), Xorg + openbox, several apps placed per screen, touch, nvidia-safe, read-only root in production, monitored, remote-manageable over SSH.

Status: implemented and tested on the first device (Lenovo, Intel UHD 730, Ubuntu 26.04.1, Chrome 155): autoinstall, base setup, X11 session, app types web/static/video/slideshow/launcher with per-screen placement, static apps with up to five data repos and Git LFS, Chrome extensions by policy, services (tunnel, WLAN, USB action, audio, scheduler, health checks, unattended updates, performance), monitoring with heartbeat, persistence modes, automated benchmarks, config validation, dev tools. See `docs/architecture.md` for the decisions and `docs/open-questions.md` for what is still open.

## Install workflow

1. Install the OS unattended: `autoinstall/make-iso.sh --iso <ubuntu-server.iso> --hostname kiosk-01 --disk /dev/diskN` repacks the stock ISO with the install config and writes it to one USB stick. Boot the PC from it and wait; no keypress needed. (Alternative with two sticks: stock ISO on stick 1, `autoinstall/make-cidata.sh --hostname kiosk-01 --disk /dev/diskN` on stick 2, boot from stick 1 and confirm the autoinstall prompt once.) The one-stick ISO builds and is the intended path; it has not yet been booted on hardware, the two-stick path has.
2. Connect over SSH (`ssh kioskadmin@<hostname>`). The repo is already cloned to `/opt/kiosksystem` by the installer.
3. Run `sudo /opt/kiosksystem/setup.sh` for the base system: cleanup, kiosk user, security, performance, display stack, default config.
4. Install the app types you need, e.g. `sudo /opt/kiosksystem/apps/static/install.sh` (web, static, video, slideshow, launcher).
5. Edit `/opt/kiosk/config/kiosk.yaml`. Secrets: fill `secrets/common/` and `secrets/<hostname>/` on your machine (git-ignored, templates in `secrets.example/`) and push them with `tools/secrets.sh push <hostname> kioskadmin@<ip>`, which also runs `kioskctl apply`.
6. Optional: `sudo /opt/kiosksystem/tools/install.sh` for dev tools with checkboxes.
7. For production: `sudo kioskctl storage init` (if the install did not create the persistent volume), choose the persistence mode with `sudo kioskctl mount locked` (or `data`, `data+journal`), reboot.

Manual OS install without autoinstall: install Ubuntu Server, then run `bootstrap.sh` (installs git and openssh, clones the repo) and continue at step 2.

## Repository layout

| Directory | Purpose |
|---|---|
| `autoinstall/` | unattended Ubuntu install |
| `lib/` | shared shell helpers (`common.sh`) |
| `core/` | base-OS modules run by `setup.sh` |
| `display/` | Xorg/openbox session, drivers, screen and touch config |
| `apps/` | app types: web, nuxt-static, video, slideshow, launcher |
| `services/` | services with config sections: tunnel, wifi, usb, audio, security, scheduler, telegram, performance, health, updates, persistence |
| `config/` | default config (`kiosk.default.yaml`); validation rules in `lib/config-check.jq` |
| `bin/` | `kioskctl` |
| `monitoring/` | collector, status, heartbeat |
| `server/` | optional heartbeat receiver |
| `tests/` | stress test, benchmarks, DevTools client |
| `tools/` | dev-tools installer |
| `branding/` | boot theme, backgrounds |
| `secrets.example/` | templates for device secrets |
| `docs/` | not in this repo: the documentation lives in the private repo `jewe/kiosk-docs` (clone it into `docs/`). Paths like `docs/config.md` in `kioskctl help` refer to it |
| `examples/` | example extension, deploy script for the build branch |
