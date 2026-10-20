# tools — optional developer tools

`install.sh` (whiptail checklist or arguments): `node`, `vscode`, `mate` (caja, mate-terminal, pluma), `htop` (htop, nvtop, iotop, ncdu), `glmark2`, `devmode`.

Dev mode (`kioskctl devmode on|off`) swaps the openbox config for `display/openbox/rc-dev.xml`: Ctrl+Alt+T terminal, Ctrl+Alt+F caja, Ctrl+Alt+C vscode, Alt+Tab, Ctrl+Alt+Q close window, Alt+drag to move/resize, mouse pointer visible. Off in production. `kioskctl files` shows the pointer too; `kioskctl cursor hide` hides it again.

`screenshot.sh [file]`: screenshot with scrot (`kioskctl screenshot`). Versioning: the patch number in `VERSION` increments automatically on every commit through `.githooks/pre-commit` (activate once per clone: `git config core.hooksPath .githooks`). `release.sh minor|major` bumps the other parts, tags and pushes. `kioskctl version` and status show `major.minor.patch (git describe)`.

`secrets.sh push|pull <name> <user@host>`: copy the git-ignored `secrets/` folder to a device (root-only permissions, then apply) or pull the device's generated keys back.
