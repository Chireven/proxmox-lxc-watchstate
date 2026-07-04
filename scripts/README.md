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

The script has been validated against the native WatchState LXC deployment. A successful run should report all services active and the WatchState healthcheck should return healthy.

Expected successful service/healthcheck result:

```text
active
active
active
{"status":"ok","message":"System is healthy"}
```

The generated archives were also validated by restoring them into a clean scratch CT and confirming Redis, the WatchState web service, the scheduler service, and the API healthcheck returned healthy.

Do not commit generated backup archives or copied runtime data to this repository.
