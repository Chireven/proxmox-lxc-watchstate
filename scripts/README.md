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

The script exits non-zero if any required check fails. Warnings do not fail the script but should be reviewed.

## update-watchstate.sh

Updates the native WatchState LXC deployment from the Proxmox host.

Run from the Proxmox host:

```bash
chmod +x scripts/update-watchstate.sh
./scripts/update-watchstate.sh
```

If no CT ID is supplied, the script looks for a Proxmox CT named `watchstate`.

The update script runs a backup, creates a snapshot, updates source/dependencies/frontend/database state, restarts services, and runs verification.

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

## install-watchstate.sh

Installs the native WatchState deployment into an existing Debian LXC from the Proxmox host.

This script does not create the LXC. Start with a clean Debian CT, then run the script from the Proxmox host.

By default, the install script uses the official FrankenPHP install script and then places the resulting binary at `/opt/bin/frankenphp` for this deployment.

Example:

```bash
chmod +x scripts/install-watchstate.sh
./scripts/install-watchstate.sh --ctid 103
```

Common options:

```bash
./scripts/install-watchstate.sh --name watchstate
./scripts/install-watchstate.sh --ctid 103
./scripts/install-watchstate.sh --branch master
./scripts/install-watchstate.sh --frankenphp-install-script https://frankenphp.dev/install.sh
./scripts/install-watchstate.sh --frankenphp-url '<validated-frankenphp-binary-url>'
./scripts/install-watchstate.sh --skip-verify
./scripts/install-watchstate.sh --force
```

Use `--frankenphp-url` only when pinning a specific validated FrankenPHP binary. Otherwise, the default official install script path is simpler.

Default behavior:

```text
installs Debian package prerequisites
creates watchstate UID/GID 1000
creates /config and /opt/bin
installs Bun if missing
installs or validates /opt/bin/frankenphp
clones WatchState into /opt/app
runs Composer install
runs Bun install
generates and syncs frontend output
runs initial WatchState console/database initialization
installs systemd service units
starts Redis, web, and scheduler services
runs verify-watchstate.sh
```

The install script is newly produced and still needs validation in a clean scratch CT before being considered complete.

Do not commit generated backup archives or copied runtime data to this repository.
