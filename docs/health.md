# Health checks

`services.health` restarts a web or static app that is running but shows nothing. The kiosk app resets itself and always looks similar, so the check does not compare pictures. It looks for the states a broken Chrome actually produces:

| Check | Broken indicator | Why it catches real failures |
|---|---|---|
| `window` | the unit is active but no visible X window has the class `kiosk-<name>` | Chrome crashed without exiting, or never mapped its window after a text console was active |
| `title` | the window title is empty, `Untitled`, `about:blank`, `Aw, Snap` or a "can't be reached" page | the renderer died (seen on kiosk-01: a blank window titled "Untitled"), or nginx was down when the page loaded |
| `http` | static apps only: `http://127.0.0.1:<port>/` does not answer 200 | nginx site broken or stopped |
| `screen` | the window area is one flat colour (pixel standard deviation below `min_stddev`, 0–255 scale) | a page that loaded but renders nothing (JS error before first paint, GPU process gone). Off by default: costs a screenshot per app per interval and needs imagemagick |

An app younger than 45 s is skipped (still starting), stopped apps are skipped (schedule or admin), and nothing runs while a text console is active.

Action: `systemctl restart` of the app unit. After three restarts of the same app within 30 minutes the whole session is restarted once instead. Every action is logged to the journal with tag `kiosk-health` as JSON (`ts`, `app`, `reason`, `action`) and, when Telegram is enabled, a screenshot with the reason is sent.

```yaml
services:
  health:
    enabled: true
    interval: 2m
    checks: [window, title, http]     # add screen for the flat-colour test
    min_stddev: 3
```

Dry run on the device: `sudo /opt/kiosksystem/services/health/check.sh --dry-run` prints what would be restarted without doing it. History: `journalctl -t kiosk-health`.

What it does not catch: a page that shows stale but valid content (that is the job of the content update and `kioskctl status` repo lines), and touch input that stopped working (no signal available without a user).
