# secrets (git-ignored)

Local copies of device secrets. Nothing in here except this file is committed.

```
secrets/
├── common/        shared by all devices: wifi.env, monitoring.env, telegram.env
└── kiosk-01/      per device: overrides common/, plus keys generated on the device (git/, tunnel/)
```

Templates: `../secrets.example/`. Push to a device: `tools/secrets.sh push kiosk-01 kioskadmin@192.168.10.187`.
Pull keys the device generated (deploy key, tunnel key) into `secrets/<name>/`: `tools/secrets.sh pull kiosk-01 kioskadmin@…`.
