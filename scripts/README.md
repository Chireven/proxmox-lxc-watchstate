# Scripts

This directory contains host-side helper scripts for the native WatchState LXC deployment.

## backup-watchstate.sh

Creates an application-level backup of the validated WatchState LXC deployment.

Run from the Proxmox host:

```bash
chmod +x scripts/backup-watchstate.sh
./scripts/backup-watchstate.sh
```

Default settings:

```text
CT ID: 103
backup root: /root/watchstate-backups
include app tree: yes
```

Common options:

```bash
./scripts/backup-watchstate.sh --ctid 103 --backup-root /mnt/backups/watchstate
./scripts/backup-watchstate.sh --no-app
./scripts/backup-watchstate.sh --keep-tmp
```

After running, confirm the script reports all services active and the WatchState healthcheck returns healthy.
