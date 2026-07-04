# Phase 8 - Backup and Restore Procedure

This document defines the native LXC backup and restore approach for the validated WatchState installation.

## Current Validated Layout

Runtime identity:

```text
CT: 103
hostname: watchstate
service user: watchstate
service group: watchstate
```

Application paths:

```text
/opt/app      WatchState source tree
/opt/bin      FrankenPHP and helper commands
/config       persistent WatchState runtime data
```

Systemd services:

```text
redis-server.service
watchstate-web.service
watchstate-scheduler.service
```

Validated checkpoint before this procedure:

```text
watchstate-phase-6-app-configured
```

## Backup Scope

The backup must protect the persistent application state and enough deployment metadata to rebuild the service cleanly.

Required backup content:

```text
/config
/etc/systemd/system/watchstate-web.service
/etc/systemd/system/watchstate-scheduler.service
/opt/bin/frankenphp
```

Recommended metadata capture:

```text
hostnamectl
systemctl is-enabled redis-server watchstate-web watchstate-scheduler
systemctl status redis-server watchstate-web watchstate-scheduler --no-pager
/opt/bin/frankenphp --version
redis-cli ping
```

Optional backup content:

```text
/opt/app
```

Rationale:

- `/config` is mandatory because it contains WatchState runtime configuration, database, queues, generated app state, and user/server settings.
- The systemd unit files are mandatory because they define the native service model.
- `/opt/bin/frankenphp` is recommended because this build intentionally uses a validated FrankenPHP binary.
- `/opt/app` can be reconstructed from upstream source and build steps, but backing it up makes same-version rollback faster.

## Public Repository Safety

Do not commit backup archives, live config, database files, generated server files, logs, or private deployment values to this repository.

This repository should only contain generic commands and procedures.

## Host-Side Backup Script

The validated helper script is:

```text
scripts/backup-watchstate.sh
```

Run from the Proxmox host:

```bash
/scripts/backups/backup-watchstate.sh --ctid 103
```

The script creates a timestamped backup directory under `/root/watchstate-backups` by default and includes:

```text
watchstate-config.tgz
watchstate-systemd.tgz
watchstate-frankenphp.tgz
watchstate-app.tgz
metadata-before.txt
metadata-after.txt
README.txt
```

The script stops WatchState web/scheduler services, creates archives inside the CT, pulls them to the host, restarts services, and validates the service/healthcheck state.

Expected successful result:

```text
active
active
active
{"status":"ok","message":"System is healthy"}
```

## Manual Backup Procedure

Run from the Proxmox host.

Set variables:

```bash
CTID=103
STAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP_DIR="/root/watchstate-backups/${STAMP}"
mkdir -p "${BACKUP_DIR}"
```

Stop WatchState services for a consistent application-level backup:

```bash
pct exec "${CTID}" -- systemctl stop watchstate-scheduler.service
pct exec "${CTID}" -- systemctl stop watchstate-web.service
```

Keep Redis running unless a specific Redis dump is later required. Current WatchState persistent state is file-backed under `/config`.

Create archives from inside the container:

```bash
pct exec "${CTID}" -- tar --xattrs --acls -czf /tmp/watchstate-config.tgz -C / config
pct exec "${CTID}" -- tar --xattrs --acls -czf /tmp/watchstate-systemd.tgz -C / etc/systemd/system/watchstate-web.service etc/systemd/system/watchstate-scheduler.service
pct exec "${CTID}" -- tar --xattrs --acls -czf /tmp/watchstate-frankenphp.tgz -C / opt/bin/frankenphp
```

Optional same-version application tree backup:

```bash
pct exec "${CTID}" -- tar --xattrs --acls -czf /tmp/watchstate-app.tgz -C / opt/app
```

Pull archives to the Proxmox host:

```bash
pct pull "${CTID}" /tmp/watchstate-config.tgz "${BACKUP_DIR}/watchstate-config.tgz"
pct pull "${CTID}" /tmp/watchstate-systemd.tgz "${BACKUP_DIR}/watchstate-systemd.tgz"
pct pull "${CTID}" /tmp/watchstate-frankenphp.tgz "${BACKUP_DIR}/watchstate-frankenphp.tgz"

# Optional if created:
pct pull "${CTID}" /tmp/watchstate-app.tgz "${BACKUP_DIR}/watchstate-app.tgz"
```

Capture metadata:

```bash
{
  echo "Backup timestamp UTC: ${STAMP}"
  echo
  pct exec "${CTID}" -- hostnamectl
  echo
  pct exec "${CTID}" -- systemctl is-enabled redis-server.service watchstate-web.service watchstate-scheduler.service
  echo
  pct exec "${CTID}" -- /opt/bin/frankenphp --version
  echo
  pct exec "${CTID}" -- redis-cli ping
  echo
  pct exec "${CTID}" -- curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck || true
} > "${BACKUP_DIR}/metadata.txt"
```

Clean temporary archives from the container:

```bash
pct exec "${CTID}" -- rm -f /tmp/watchstate-config.tgz /tmp/watchstate-systemd.tgz /tmp/watchstate-frankenphp.tgz /tmp/watchstate-app.tgz
```

Restart WatchState services:

```bash
pct exec "${CTID}" -- systemctl start watchstate-web.service
pct exec "${CTID}" -- systemctl start watchstate-scheduler.service
```

Validate after backup:

```bash
pct exec "${CTID}" -- systemctl is-active redis-server.service watchstate-web.service watchstate-scheduler.service
pct exec "${CTID}" -- curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck
```

Expected:

```text
active
active
active
{"status":"ok","message":"System is healthy"}
```

## Backup Validation Result

The manual backup procedure and `scripts/backup-watchstate.sh` were both run successfully from the Proxmox host.

Post-backup service validation returned:

```text
active
active
active
{"status":"ok","message":"System is healthy"}
```

This confirms that the backup sequence can stop the WatchState services, create and pull backup archives, restart the services, and return the application to a healthy state.

## Proxmox Snapshot Procedure

Application-level backups should be paired with Proxmox snapshots at major milestones.

Known snapshots:

```text
watchstate-phase-5-frankenphp-validated
watchstate-phase-5-services-validated
watchstate-phase-6-app-configured
watchstate-pre-update-validation
```

Before risky changes:

```bash
pct snapshot 103 watchstate-before-change-YYYYMMDD --description "WatchState checkpoint before change"
```

Snapshots are fast rollback points, but they are not a replacement for off-host backups.

## Restore Procedure

The restore procedure was validated by restoring the generated archives into a clean scratch CT and confirming the restored application returned healthy.

Important command context:

- Commands shown with `pct exec <CTID> --` are run from the Proxmox host and execute inside the target CT.
- Raw `groupadd`, `useradd`, `chown`, `tar`, and `systemctl` commands must only be used from a shell already inside the target CT.
- Do not run restore-target identity or ownership commands directly on the Proxmox host.

Restore target assumptions:

```text
Target CT is a clean Debian LXC.
Required packages are installed, including ca-certificates, curl, git, tar, acl, redis-server, and rsync.
Backup archives are available on the Proxmox host.
```

Copy backup archives into the restore target CT:

```bash
RESTORE_CTID=113
BACKUP_DIR="/root/watchstate-backups/YYYYMMDD-HHMMSS"

pct push "${RESTORE_CTID}" "${BACKUP_DIR}/watchstate-config.tgz" /tmp/watchstate-config.tgz
pct push "${RESTORE_CTID}" "${BACKUP_DIR}/watchstate-systemd.tgz" /tmp/watchstate-systemd.tgz
pct push "${RESTORE_CTID}" "${BACKUP_DIR}/watchstate-frankenphp.tgz" /tmp/watchstate-frankenphp.tgz
pct push "${RESTORE_CTID}" "${BACKUP_DIR}/watchstate-app.tgz" /tmp/watchstate-app.tgz
```

Verify archives inside the CT. Use a shell because `pct exec` does not expand wildcards unless a shell is invoked:

```bash
pct exec "${RESTORE_CTID}" -- sh -c 'ls -lh /tmp/watchstate-*.tgz'
pct exec "${RESTORE_CTID}" -- find /tmp -maxdepth 1 -name 'watchstate-*.tgz' -ls
```

Create the service identity inside the restore target CT before starting services:

```bash
pct exec "${RESTORE_CTID}" -- sh -c 'getent group 1000 >/dev/null || groupadd -g 1000 watchstate'
pct exec "${RESTORE_CTID}" -- sh -c 'id -u watchstate >/dev/null 2>&1 || useradd -u 1000 -g 1000 -d /config -s /usr/sbin/nologin watchstate'
```

Extract archives inside the restore target CT:

```bash
pct exec "${RESTORE_CTID}" -- sh -c 'systemctl stop watchstate-scheduler.service watchstate-web.service 2>/dev/null || true'

pct exec "${RESTORE_CTID}" -- tar --xattrs --acls -xzf /tmp/watchstate-config.tgz -C /
pct exec "${RESTORE_CTID}" -- tar --xattrs --acls -xzf /tmp/watchstate-systemd.tgz -C /
pct exec "${RESTORE_CTID}" -- tar --xattrs --acls -xzf /tmp/watchstate-frankenphp.tgz -C /
pct exec "${RESTORE_CTID}" -- tar --xattrs --acls -xzf /tmp/watchstate-app.tgz -C /

pct exec "${RESTORE_CTID}" -- chown -R watchstate:watchstate /config /opt/app
```

Verify restored paths:

```bash
pct exec "${RESTORE_CTID}" -- ls -ld /config /opt/app /opt/bin
pct exec "${RESTORE_CTID}" -- sh -c 'ls -l /etc/systemd/system/watchstate-*.service'
pct exec "${RESTORE_CTID}" -- /opt/bin/frankenphp --version
pct exec "${RESTORE_CTID}" -- id watchstate
```

Reload systemd and start services:

```bash
pct exec "${RESTORE_CTID}" -- systemctl daemon-reload
pct exec "${RESTORE_CTID}" -- systemctl enable redis-server.service watchstate-web.service watchstate-scheduler.service
pct exec "${RESTORE_CTID}" -- systemctl start redis-server.service watchstate-web.service watchstate-scheduler.service
```

Validate:

```bash
pct exec "${RESTORE_CTID}" -- systemctl is-active redis-server.service watchstate-web.service watchstate-scheduler.service
pct exec "${RESTORE_CTID}" -- curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck
```

Expected:

```text
active
active
active
{"status":"ok","message":"System is healthy"}
```

## Restore Validation Result

Restore testing was completed against a scratch CT.

Validated result:

```text
redis-server.service: active
watchstate-web.service: active
watchstate-scheduler.service: active
healthcheck: healthy
```

The scratch restore CT was removed after validation.

Key restore lessons:

- `pct exec` does not expand shell wildcards unless wrapped in `sh -c`.
- Service identity creation and ownership fixes must run inside the restore target CT.
- The restored `/config` and `/opt/app` trees must be owned by `watchstate:watchstate`.
- Locale warnings in a minimal Debian scratch CT did not block restore validation.

## Open Items

- Decide retention location and retention policy for host-side backup archives.
- Decide whether the backup script should enforce retention automatically or only create point-in-time backups.
- Optionally polish backup script healthcheck output formatting.
