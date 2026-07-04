# Scripts

This directory contains host-side helper scripts for the native WatchState LXC deployment.

## backup-watchstate.sh

Creates an application-level backup of the validated WatchState LXC deployment.

Run from the Proxmox host:

```bash
chmod +x scripts/backup-watchstate.sh
./scripts/backup-watchstate.sh
```

If no CT ID is supplied, the script looks for a Proxmox CT named `watchstate`.

Default settings:

```text
CT name: watchstate
backup root: /root/watchstate-backups
include app tree: yes
retention: keep latest 14 backup directories
```

Common options:

```bash
./scripts/backup-watchstate.sh --name watchstate
./scripts/backup-watchstate.sh --ctid 103 --backup-root /mnt/backups/watchstate
./scripts/backup-watchstate.sh --no-app
./scripts/backup-watchstate.sh --keep-tmp
```

Retention and listing options:

```bash
./scripts/backup-watchstate.sh --list
./scripts/backup-watchstate.sh --keep 30
./scripts/backup-watchstate.sh --keep 0
./scripts/backup-watchstate.sh --prune-only
./scripts/backup-watchstate.sh --prune-only --prune-dry-run
```

Retention is count-based, not age-based. By default, the script keeps the latest 14 timestamp-style backup directories under the selected backup root and prunes older matching directories after a successful backup. Use `--keep 0` to disable pruning.

The prune logic only targets directories with names matching this timestamp format:

```text
YYYYMMDD-HHMMSS
```

The script refuses to prune directly under broad system paths such as `/`, `/root`, `/mnt`, `/var`, `/opt`, `/etc`, or `/usr`. Use a dedicated backup root such as `/root/watchstate-backups` or `/mnt/backups/watchstate`.

The script has been validated against the native WatchState LXC deployment. A successful run should report all services active and the WatchState healthcheck should return healthy.

Expected successful service/healthcheck result:

```text
active
active
active
{"status":"ok","message":"System is healthy"}
```

The generated archives were also validated by restoring them into a clean scratch CT and confirming Redis, the WatchState web service, the scheduler service, and the API healthcheck returned healthy.

## verify-watchstate.sh

Verifies the native WatchState LXC deployment from the Proxmox host.

Run from the Proxmox host:

```bash
chmod +x scripts/verify-watchstate.sh
./scripts/verify-watchstate.sh
```

If no CT ID is supplied, the script looks for a Proxmox CT named `watchstate`.

Explicit examples:

```bash
./scripts/verify-watchstate.sh --name watchstate
./scripts/verify-watchstate.sh --ctid 103
```

The verification script checks:

```text
container status
service user/group
required paths
systemd enabled/active state
FrankenPHP version
Redis PONG
WatchState healthcheck
Git branch/remote/status
required tools
Composer platform requirements
WatchState database presence
migration dry-run status
frontend output presence
```

The script exits non-zero if any required check fails. Warnings do not fail the script but should be reviewed.

## update-watchstate.sh

Updates the native WatchState LXC deployment from the Proxmox host.

Run from the Proxmox host:

```bash
chmod +x scripts/update-watchstate.sh
./scripts/update-watchstate.sh
```

If no CT ID is supplied, the script looks for a Proxmox CT named `watchstate`.

Default behavior:

```text
runs backup-watchstate.sh first
creates a Proxmox snapshot
stops WatchState web/scheduler services
fast-forwards origin/master
runs Composer install
runs Bun install
regenerates frontend output
syncs frontend/exported to public/exported
executes database migrations
runs database index/cache maintenance
restarts services
runs verify-watchstate.sh
```

Common options:

```bash
./scripts/update-watchstate.sh --name watchstate
./scripts/update-watchstate.sh --ctid 103
./scripts/update-watchstate.sh --branch master
./scripts/update-watchstate.sh --backup-root /mnt/backups/watchstate
./scripts/update-watchstate.sh --skip-snapshot
./scripts/update-watchstate.sh --skip-backup
./scripts/update-watchstate.sh --skip-verify
```

The update script is based on the validated Phase 9 update procedure. Test it during a maintenance window before treating it as production automation.

Do not commit generated backup archives or copied runtime data to this repository.
