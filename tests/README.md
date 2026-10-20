# tests — stress test, benchmarks

- `stress.sh [minutes] [events/s]` (`kioskctl test stress`): random clicks, drags, scrolls and keys via xdotool, memory sampled every 30 s to `/opt/kiosk/data/stress/*.csv`. PASS = no app restarts and memory growth under 10 %.
- `bench.sh info|gpu|motionmark|ab` (`kioskctl bench`): GPU/driver/VA-API report incl. `chrome://gpu`, glmark2 score (about 8 minutes), MotionMark with the production Chrome flags (about 6 minutes, score via DevTools, `cdp.py`), A/B of two flag sets. Journal tag `kiosk-bench`, JSON in `/opt/kiosk/data/bench/`. See `docs/performance.md`.
- `cdp.py PORT pages|nav|eval|wait`: small DevTools client (standard library only) used by bench.sh.
- `kioskctl doctor` is the install self-test.
