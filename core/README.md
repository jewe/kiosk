# core — numbered, idempotent base-OS modules run by `setup.sh`

| Module | Does |
|---|---|
| 01_cleanup | remove snap, unattended-upgrades, disable cloud-init, motd noise |
| 02_user | `kiosk` user, groups, `/opt/kiosk` layout, `kioskctl` symlink, sudoers |
| 03_security | ufw, sshd hardening (password login off only when a key exists) |
| 04_performance | governor, no sleep, sysctl |
| 05_packages | yq, jq, sensors, NetworkManager, pipewire |
| 06_persistence | overlayroot package, journald limits (mode via `kioskctl mount`) |
| 07_watchdog | systemd hardware watchdog |
| 08_display | → `display/install.sh` |
| 09_branding | → `branding/install.sh` |
| 10_config | default `kiosk.yaml`, secrets templates, first `kioskctl apply` |
