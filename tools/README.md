# tools — optional developer tools

`install.sh` (whiptail checklist or arguments): `node`, `vscode`, `mate` (caja, mate-terminal, pluma), `htop` (htop, nvtop, iotop, ncdu), `glmark2`, `devmode`.

Dev mode (`kioskctl devmode on|off`) swaps the openbox config for `display/openbox/rc-dev.xml`: Ctrl+Alt+T terminal, Ctrl+Alt+F caja, Ctrl+Alt+C vscode, Alt+Tab, Ctrl+Alt+Q close window, Alt+drag to move/resize. Off in production.

`screenshot.sh [file]`: screenshot with scrot (`kioskctl screenshot`). `release.sh patch|minor|major`: bump `VERSION`, tag and push; `kioskctl version` and status show `major.minor.patch (git describe)`.
