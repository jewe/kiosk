# Keyboard shortcuts

## On the kiosk (keyboard plugged in)

| Keys | Effect | Available |
|---|---|---|
| Ctrl+Alt+F1 | back to the kiosk screen (tty1) | always |
| Ctrl+Alt+F2 … F6 | text console (login as kioskadmin). **The kiosk screen is paused while a console is active**; press Ctrl+Alt+F1 to return, or run `sudo kioskctl display` | always |
| Ctrl+Alt+Backspace | nothing (killing X is disabled) | — |
| Ctrl+Alt+T | terminal (mate-terminal, else x-terminal-emulator) | dev mode |
| Ctrl+Alt+F | file manager caja | dev mode, after `tools/install.sh mate` |
| Ctrl+Alt+C | Visual Studio Code | dev mode, after `tools/install.sh vscode` |
| Ctrl+Alt+Q | close the focused window | dev mode |
| Alt+Tab | next window | dev mode |
| Alt + left drag / Alt + right drag | move / resize a window | dev mode |

In production mode openbox has no key bindings at all, and Chrome runs in kiosk mode: no address bar, no tabs, no F11/F12. A plugged-in keyboard can type into the web app but cannot leave it.

Dev mode: `sudo kioskctl devmode on|off` (switches the openbox bindings live and shows the mouse pointer). Status: `kioskctl devmode`.

## From the admin shell (SSH)

| Command | Effect |
|---|---|
| `kioskctl status` / `doctor` / `history` | summary, self-test, metric history |
| `sudo kioskctl apply` | apply `/opt/kiosk/config/kiosk.yaml` |
| `sudo kioskctl app restart <name>` / `app update <name>` / `app logs <name>` | app control |
| `sudo kioskctl display` | re-apply screens and touch, return to tty1 |
| `sudo kioskctl screenshot [--telegram]` | screenshot to file / to Telegram |
| `sudo kioskctl files` / `cursor show|hide` | caja on the kiosk screen, pointer visibility |
| `sudo kioskctl usb mount|umount` | USB stick at /media/usb |
| `sudo kioskctl mount rw|data|data+journal|locked` | persistence mode, then reboot |
| `sudo kioskctl update` | pull the system repo and re-run setup (rw mode) |
| `sudo kioskctl secrets git-key <label>` | deploy key for a private repo |
| `sudo kioskctl test stress [min]` / `bench gpu` | stress test, benchmark |
