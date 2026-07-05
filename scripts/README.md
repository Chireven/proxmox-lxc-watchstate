# Scripts

This directory contains host-side helper scripts for the native WatchState LXC deployment.

The scripts are intended to run from the Proxmox host. They use `pct exec` to make changes inside the target CT.

Validated host-side standalone location:

```text
/scripts/watchstate
```

## install-watchstate.sh

Installs the native WatchState deployment into an existing Debian LXC from the Proxmox host.

This script does not create the LXC. Start with a clean Debian CT, then run the script from the Proxmox host.

The install script can run from either the full repository layout or from a copied standalone scripts directory. If the `systemd/` service templates are not found next to the script or one directory above it, the script writes embedded WatchState service units into the target CT.

By default, the script downloads the latest FrankenPHP static binary for the CT architecture and installs it to `/opt/bin/frankenphp`.

Run from the Proxmox host:

```bash
chmod +x install-watchstate.sh verify-watchstate.sh
./install-watchstate.sh --ctid 103
```

Common options:

```bash
./install-watchstate.sh --name watchstate
./install-watchstate.sh --ctid 103
./install-watchstate.sh --branch master
./install-watchstate.sh --frankenphp-url '<validated-frankenphp-binary-url>'
./install-watchstate.sh --skip-verify
./install-watchstate.sh --force
```

Use `--frankenphp-url` only when pinning a specific validated FrankenPHP binary. Otherwise, the default latest static binary path is simpler.

Default behavior:

```text
installs Debian package prerequisites
creates watchstate UID/GID 1000
creates /config, /opt/app, and /opt/bin
installs Bun to /usr/local/bin/bun if missing
installs or validates /opt/bin/frankenphp
clones WatchState into /opt/app
runs Composer install
runs Bun install
generates and syncs frontend output
runs initial WatchState console/database initialization
installs systemd service units
starts Redis, web, and scheduler services
runs verify-watchstate.sh when available
```

## verify-watchstate.sh

Verifies the native WatchState LXC deployment from the Proxmox host.

Run from the Proxmox host:

```bash
chmod +x verify-watchstate.sh
./verify-watchstate.sh
```

If no CT ID is supplied, the script looks for a Proxmox CT named `watchstate`.

Explicit examples:

```bash
./verify-watchstate.sh --name watchstate
./verify-watchstate.sh --ctid 103
./verify-watchstate.sh --ctid 103 --json
./verify-watchstate.sh --ctid 103 --no-color
```

The script exits non-zero if any required check fails. Warnings do not fail the script but should be reviewed.

The verifier checks host/container state, identity, paths, service health, runtime health, Git state, required tools, frontend output, database presence, and migration dry-run status. Output is color-coded when running in an interactive terminal.

## backup-watchstate.sh

Creates an application-level backup of the validated WatchState LXC deployment.

Run from the Proxmox host:

```bash
chmod +x backup-watchstate.sh
./backup-watchstate.sh
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
./backup-watchstate.sh --name watchstate
./backup-watchstate.sh --ctid 103 --backup-root /mnt/backups/watchstate
./backup-watchstate.sh --no-app
./backup-watchstate.sh --keep-tmp
```

Retention and listing options:

```bash
./backup-watchstate.sh --list
./backup-watchstate.sh --keep 30
./backup-watchstate.sh --keep 0
./backup-watchstate.sh --prune-only
./backup-watchstate.sh --prune-only --prune-dry-run
```

Retention is count-based, not age-based. By default, the script keeps the latest 14 timestamp-style backup directories under the selected backup root and prunes older matching directories after a successful backup. Use `--keep 0` to disable pruning.

The prune logic only targets directories with names matching this timestamp format:

```text
YYYYMMDD-HHMMSS
```

The script refuses to prune directly under broad system paths such as `/`, `/root`, `/mnt`, `/var`, `/opt`, `/etc`, or `/usr`. Use a dedicated backup root such as `/root/watchstate-backups` or `/mnt/backups/watchstate`.

The script has been validated against the native WatchState LXC deployment. A successful run should report all services active and the WatchState healthcheck should return healthy.

## update-watchstate.sh

Updates the native WatchState LXC deployment from the Proxmox host.

Run from the Proxmox host:

```bash
chmod +x update-watchstate.sh
./update-watchstate.sh
```

If no CT ID is supplied, the script looks for a Proxmox CT named `watchstate`.

The update script runs a backup, creates a snapshot, updates source/dependencies/frontend/database state, restarts services, validates service health, and runs verification.

Common options:

```bash
./update-watchstate.sh --name watchstate
./update-watchstate.sh --ctid 103
./update-watchstate.sh --branch master
./update-watchstate.sh --backup-root /mnt/backups/watchstate
./update-watchstate.sh --skip-snapshot
./update-watchstate.sh --skip-backup
./update-watchstate.sh --skip-verify
```

## Important implementation notes

- Bun is installed at `/usr/local/bin/bun`.
- Non-login `pct exec ... sh -c` sessions may not include `/usr/local/bin` in `PATH`.
- The validated scripts either call `/usr/local/bin/bun` directly or export a PATH containing `/usr/local/bin` before running Composer scripts that invoke `bun` by name.
- FrankenPHP is installed at `/opt/bin/frankenphp`.
- Do not commit generated backup archives, copied runtime data, logs, database files, private URLs, or host-specific configuration.
