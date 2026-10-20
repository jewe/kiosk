# Architecture

Decisions for the kiosk system, taken 2026-10-16 from `requirements.md` and a review of the earlier `kiosk26` attempt. Each decision lists what was chosen and why. Open items are in `open-questions.md`.

## Goal

A git repository that turns a bare x86 PC into an appliance-grade Linux kiosk that runs for years: fully scriptable over SSH, still usable on-site with keyboard and mouse, several apps at once placed per screen, touch, nvidia-safe, monitored, read-only root in production.

## Decisions

### D1. Display stack: X11 (Xorg + openbox)

Chosen over Wayland (cage, as in kiosk26) because every hard requirement has a known X11 solution:

| Requirement | X11 mechanism |
|---|---|
| nvidia screen tearing | `ForceCompositionPipeline` in xorg.conf.d |
| projector / wall transform | `xrandr --transform` |
| touchscreen to one output | `xinput --map-to-output` |
| window placement per screen | `wmctrl` / `xdotool` |
| multiscreen, spanning | `xrandr` |

The session layer (`display/`) is kept thin so a Wayland session can be added later for Intel-only devices.

### D2. Base OS: Ubuntu Server LTS, installed unattended

Written for 24.04; the first device was installed with 26.04.1 LTS and everything in milestone 1 worked there, so 26.04 is the current target.

Server, not Ubuntu MATE: only what we install is on the box. MATE helpers such as caja are an optional dev-tools module.

OS installation uses Ubuntu's built-in autoinstall:

- Two USB sticks. Stick 1 is the stock Ubuntu Server ISO. Stick 2 is a small FAT volume labeled `CIDATA` holding `user-data` and `meta-data`. cloud-init's NoCloud datasource picks it up automatically.
- The installer asks once whether to continue with autoinstall. One keypress, no GRUB editing.
- `autoinstall/make-cidata.sh` runs on the Mac and renders `user-data.template` with hostname and SSH public key, then builds the stick.
- The template sets locale, keyboard, timezone, hostname, an admin user with SSH key only, packages `openssh-server` and `git`, no snaps, and a `late-command` that clones this repo to `/opt/kiosksystem`.
- Storage: LVM with a root LV (default 24G) and a separate `kiosk-data` LV (default 8G) mounted at `/opt/kiosk`, sizes set when building the stick (see D5).
- Running `setup.sh` remains a manual step over SSH, as in the workflow in `requirements.md`.
- Test in a VM (UTM or VirtualBox) before real hardware.

### D3. App model: several apps at once, placed per screen

Each app is an instance of a systemd template unit (`kiosk-<type>@<name>.service`) grouped under `kiosk.target`. systemd handles restart, logging and enable/disable. There is no custom dispatcher or mode file (kiosk26's `runtime/start.sh` loop is dropped).

App types: `web` (Chrome kiosk), `nuxt-static` (nginx serving a static build plus a `web` instance), `video` (mpv loop), `slideshow` (image loop), `launcher` (any command with a configured geometry).

### D4. Configuration: one local YAML file

`/opt/kiosk/config/kiosk.yaml` is the single source of truth. `setup.sh` writes a default that already works: one web app, fullscreen on the primary screen, URL placeholder, every optional service off. A human adjusts it over SSH.

`kioskctl apply` validates the file (`yq` plus a small schema check) and renders everything derived from it: xorg.conf.d snippets, the xrandr/xinput script, per-app systemd environment files, NetworkManager profiles, PipeWire defaults, scheduler timers. It is safe to run repeatedly.

Sections: `device`, `display`, `touch`, `audio`, `apps`, `network`, `services` (each with `enabled`), `schedule`, `security`, `persistence`.

Secrets live outside the config in `/opt/kiosk/secrets/` (root, mode 0700, on the persistent volume, never in git): `wifi.env` with SSID/PSK pairs for up to three service WLANs, `tunnel/id_ed25519` and `known_hosts`, `monitoring.token`. The config references secrets by name only. `secrets.example/` in the repo is the template. Provisioning is `scp` from the Mac or `kioskctl secrets import <dir>` from a USB stick. The autoinstall template may pre-seed WLAN secrets.

### D5. Persistence: the admin chooses what survives a reboot

The read-only overlay has two purposes: every boot starts from the identical system (no cache or state drift), and SSD writes stay minimal for a long lifetime. How much is allowed to persist is a config choice, `persistence.mode`, and maps directly onto the overlayroot setting:

| Mode | root overlay | What persists | Use |
|---|---|---|---|
| `locked` | on, plus a tmpfs overlay over `/opt/kiosk` (`kiosk-locked.service`) | nothing | production default, identical start every day, near-zero writes |
| `data` | on | the `/opt/kiosk` volume: config, secrets, app repo, bench results; journal stays in RAM | devices whose content is updated remotely |
| `data+journal` | on, journal bind-mount | as `data`, plus `/var/log/journal` on the volume, high `SyncIntervalSec` | when long-term local history is wanted |
| `rw` (dev) | off | everything | development |

Rules that hold in every mode:

- The Chrome profile and cache live on tmpfs (`/run/kiosk/`), never on the volume. A reboot always clears browser state.
- Persistent monitoring history does not require a persistent journal: the heartbeat push (D7) keeps it on the receiver.
- In `locked` mode, config and app content are baked in while in `rw` mode and frozen with `kioskctl mount locked`.

`/opt/kiosk` is its own LVM volume so that `data` modes are possible. It is not required at install time. Dev mode runs with `/opt/kiosk` as a plain directory. `kioskctl storage init` creates the volume on an installed machine:

1. If the LVM volume group has free space, create a `kiosk-data` LV, format ext4, add to fstab, move the current contents over.
2. Else, if the disk has unpartitioned space, create a partition the same way.
3. Else refuse and explain that root must be shrunk offline.

`kioskctl mount locked|data|data+journal|rw` records the mode in `/etc/kiosk-persistence`, sets the kernel option `rd.overlay` through a GRUB drop-in (Ubuntu builds its initramfs with dracut since 25.10; `/etc/overlayroot.conf` is kept for initramfs-tools systems), writes the journald drop-in and asks for a reboot. While the overlay is active, all of this is written through a chroot into the read-only lower root at `/run/rootfsbase`, which is what `kioskctl` uses instead of `overlayroot-chroot`.

### D6. Updates

- App-repo auto-update at boot is a service, off by default. When enabled it pulls once the network is online, with a timeout. Failure keeps the previous version.
- OS and system-repo updates are manual via `kioskctl update`. Unattended upgrades are disabled.

### D7. Remote access and external monitoring

- autossh reverse tunnel, SSH only, optional. Server, port and key come from config and secrets. Installed and enabled only when `services.tunnel.enabled` is true.
- External monitoring is push-based so it works behind NAT. The device POSTs `kioskctl status --json` every N minutes to a URL from config. Receiver: a single-file endpoint in `server/` that stores the last JSON per device and shows a plain HTML table. Uptime Kuma's push monitor is a zero-code alternative. No alerting. Which existing project to use for history and alerts is open question #15.

### D8. Local monitoring: journald only

`kiosk-monitor.timer` runs a collector every few minutes. It writes one structured line (CPU and GPU temperature, fan, throttling, disk, RAM, load, app restart counts) to the journal under the identifier `kiosk-monitor`. `kioskctl status` and `kioskctl history` read it back. No thresholds, no actions, no database. Whether the journal survives a reboot depends on the persistence mode (D5); the heartbeat push (D7) is the long-term store in `locked` and `data` mode.

### D9. Hardware envelope: x86 from the last five years

- GPU: Intel (i915/xe) and AMD (amdgpu) through mesa; nvidia through `ubuntu-drivers install`, with the tearing fix applied automatically when nvidia is detected.
- Touch: one USB HID touchscreen mapped to one output.
- Audio: PipeWire, default sink and volume from config.
- Network: Ethernet primary. Up to three service WLANs from config with descending autoconnect priority. NetworkManager joins the first in range.

### D10. Safety and security

- SSH key only, root login off, ufw, no snap, unprivileged `kiosk` user with a narrow sudoers rule for `kioskctl`.
- systemd hardware watchdog, `Restart=always` per app, app health check hook.
- USB storage untouched by default. `security.disable_usb_storage: true` blacklists it. This conflicts with the USB-action service, and `apply` refuses both at once.
- On-site keyboard and mouse work. An escape hotkey to a terminal is part of the dev-tools module and off in production.

### D11. Tests and benchmarks

- `tests/stress.sh`: dotool clicks, touches and scrolls for N hours while sampling memory. Pass means no restarts and flat memory.
- `tests/bench.sh`: MotionMark in Chrome (production flags, score via DevTools, offline copy of MotionMark) plus glmark2, and an A/B mode for Chrome flags. Results go to the journal and `/opt/kiosk/data/bench/`. Tuning levers and reference scores: `docs/performance.md`.
- `kioskctl doctor`: self-test of every component after install.

### D12. Optional features

- Projector transform via `xrandr --transform`. Dropped if it causes trouble with nvidia or touch mapping.
- Scheduler: `schedule:` in config with per-weekday on/off times. `apply` generates systemd timers that switch screens via DPMS or `xrandr --off` and stop or start apps. Optional shutdown with `rtcwake`.
- Dev-tools installer with checkboxes (whiptail): vscode, node, MATE helpers, htop/nvtop, escape hotkey, Chrome remote debugging port.

### D13. Chrome and extensions

Google Chrome from the deb package. Not Chromium: on Ubuntu 24.04 the Chromium apt package only installs the snap, and snap-free Chromium would mean a third-party PPA. Kiosk hardening (no updates, no first-run, no password manager, no translate) goes into the policy directory `/etc/opt/chrome/policies/managed/`.

Extensions are installed through the policy `ExtensionInstallForcelist`, which works in kiosk mode. Two sources:

- A published Web Store extension: only its ID is needed.
- A private extension ("self-hosted CRX"): the `web` installer packs the extension folder once into a signed `.crx` (`google-chrome --pack-extension`), derives its ID from the key, writes a small `update.xml` next to it, and serves both from the local nginx at `http://127.0.0.1/ext/`. The policy entry is `<id>;http://127.0.0.1/ext/update.xml`. Chrome on Linux accepts non-Web-Store update URLs in this policy. The private key is kept in `/opt/kiosk/secrets/` so the ID stays stable across re-packs.

Background: the `--load-extension` flag for unpacked folders is ignored by branded Chrome since version 137, so the policy route is the supported way.

Implemented in `apps/web/extensions.sh` (`chrome.extensions` in the config, `kioskctl extension`): Web Store extensions are downloaded once and served locally as well, so a kiosk with a tmpfs profile reinstalls them at every start without internet. Details: `docs/extensions.md`.

## Components

```text
kiosk/                   git repo, cloned to /opt/kiosksystem on the device (immutable)
├── autoinstall/         user-data.template, make-cidata.sh
├── bootstrap.sh         manual install: git + openssh + clone
├── lib/common.sh        shared helpers: logging, apt_install, write_file, cfg (yq)
├── setup.sh             runs core/ modules, idempotent, --only/--skip/--dry-run
├── core/                base-OS modules, numbered
├── display/             Xorg/openbox session, drivers, tearing, xrandr/xinput from config
├── apps/<type>/         install.sh, launch.sh, kiosk-<type>@.service, config fragment
├── services/            kiosk.target, session, tunnel, app-update, usb, monitor, scheduler
├── config/              default kiosk.yaml, schema, templates
├── bin/kioskctl         control CLI
├── monitoring/          collector, status/history, heartbeat push
├── server/              optional heartbeat receiver
├── tests/               stress.sh, bench.sh, doctor checks
├── tools/               dev-tools installer
├── branding/            plymouth theme, backgrounds, startup images
├── secrets.example/     templates for /opt/kiosk/secrets
└── docs/                requirements, architecture, runbook, config reference
```

Runtime directory on the device, persistent:

```text
/opt/kiosk/
├── config/kiosk.yaml
├── secrets/
├── apps/                git-pulled app content, per-app data
├── data/                bench results, app data
├── logs/journal/        persistent journald
└── state/               scheduler and runtime state
```

`kioskctl` subcommands: `status [--json]`, `history`, `doctor`, `apply`, `app list|start|stop|enable|disable|logs`, `storage init|status`, `mount locked|data|data+journal|rw`, `update`, `secrets import`, `schedule`, `test stress`, `bench`, `version`.

## What was taken from kiosk26

Kept: the split between the immutable git checkout and the mutable runtime directory, numbered idempotent core modules driven by `setup.sh`, the systemd-only app model with `kiosk.target`, overlayroot, the plymouth theme built from a background image, snap removal, journald limits, no unattended upgrades.

Fixed: inconsistent install paths; the `runtime/start.sh` mode loop; the session unit hardcoding uid 1001 and `kiosk.target` never being wired in; `Requires=graphical.target` on a system without a display manager; the pinned nvidia 535 driver without a tearing fix; `kioskctl update` editing `overlayroot.conf` on a read-only root; non-idempotent modules; `chmod 0777 /opt`.

## Implementation status (2026-10-16)

Done and tested on kiosk-01: provisioning (autoinstall, bootstrap, setup), core OS, display stack, config and kioskctl, app types web/static/video/slideshow/launcher with per-screen placement, services tunnel/wifi/usb/audio/security, monitoring collector + heartbeat + PHP receiver, scheduler, stress test and benchmarks, dev tools and dev mode, branding.

Persistence modes verified on kiosk-01 (dracut, Ubuntu 26.04). Not yet verified on a device: nvidia and AMD paths, touch mapping, WLAN join with real credentials, tunnel against a real server, USB action with a real stick, projector transform. See `open-questions.md`.
