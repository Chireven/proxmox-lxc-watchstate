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

## Proxmox Snapshot Procedure

Application-level backups should be paired with Proxmox snapshots at major milestones.

Known snapshots:

```text
watchstate-phase-5-frankenphp-validated
watchstate-phase-5-services-validated
watchstate-phase-6-app-configured
```

Before risky changes:

```bash
pct snapshot 103 watchstate-before-change-YYYYMMDD --description "WatchState checkpoint before change"
```

Snapshots are fast rollback points, but they are not a replacement for off-host backups.

## Restore Procedure Draft

Restore should be tested before relying on backups.

High-level restore model:

1. Start from a clean Debian LXC that has the native prerequisites installed, or restore the full Proxmox container backup if available.
2. Stop WatchState services.
3. Restore `/config`.
4. Restore service unit files.
5. Restore or reinstall FrankenPHP.
6. Restore or rebuild `/opt/app`.
7. Reload systemd.
8. Enable and start services.
9. Validate Redis, services, and healthcheck.

Example restore commands after archives are available inside the target container under `/tmp`:

```bash
systemctl stop watchstate-scheduler.service watchstate-web.service || true

tar --xattrs --acls -xzf /tmp/watchstate-config.tgz -C /
tar --xattrs --acls -xzf /tmp/watchstate-systemd.tgz -C /
tar --xattrs --acls -xzf /tmp/watchstate-frankenphp.tgz -C /

# Optional if backing up the full application tree:
tar --xattrs --acls -xzf /tmp/watchstate-app.tgz -C /

systemctl daemon-reload
systemctl enable redis-server.service watchstate-web.service watchstate-scheduler.service
systemctl start redis-server.service watchstate-web.service watchstate-scheduler.service
redis-cli ping
curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck
```

## Open Validation Items

- Run the manual backup once and confirm archive creation.
- Confirm archive ownership and permissions are preserved after extraction in a test restore or scratch container.
- Decide whether `/opt/app` is always backed up or rebuilt from upstream during restore.
- Decide retention location and retention policy for host-side backup archives.
- Produce a `backup-watchstate.sh` helper script after the manual procedure is validated.
