# Phase 10 - Rollback and Uninstall Notes

This document defines rollback and uninstall guidance for the native WatchState LXC deployment.

## Scope

These notes cover the validated native LXC installation model:

```text
/opt/app      WatchState source tree
/opt/bin      FrankenPHP binary
/config       persistent WatchState runtime data
```

Systemd services:

```text
redis-server.service
watchstate-web.service
watchstate-scheduler.service
```

Host-side helper scripts:

```text
scripts/backup-watchstate.sh
scripts/verify-watchstate.sh
scripts/update-watchstate.sh
```

## Public Repository Safety

Do not commit live backup archives, config files, databases, logs, private URLs, tokens, API keys, or generated runtime data to this repository.

## Rollback Strategy

Preferred rollback options, in order:

1. **Proxmox snapshot rollback** when the entire CT should return to a previous point in time.
2. **Application-level restore** from `backup-watchstate.sh` archives when only WatchState state should be restored.
3. **Rebuild/redeploy** from source plus restored `/config` when the app tree is damaged but persistent state is intact.

For updates, always create both:

```text
application-level backup
Proxmox snapshot
```

The validated `update-watchstate.sh` script does both by default.

## Before Rolling Back

Run from the Proxmox host.

Set the CT target:

```bash
WS_CTID=103
```

Capture current health and service state:

```bash
pct exec "${WS_CTID}" -- systemctl is-active redis-server.service watchstate-web.service watchstate-scheduler.service || true
pct exec "${WS_CTID}" -- curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck || true
```

List available application-level backups:

```bash
./scripts/backup-watchstate.sh --list
```

List Proxmox snapshots:

```bash
pct listsnapshot "${WS_CTID}"
```

## Snapshot Rollback

Use snapshot rollback when you need to revert the entire CT, including OS packages, app files, `/config`, service state, and any other CT filesystem changes.

Run from the Proxmox host.

Stop the CT if required by the Proxmox storage/backend state:

```bash
pct shutdown "${WS_CTID}" --timeout 60 || true
```

Rollback to the selected snapshot:

```bash
pct rollback "${WS_CTID}" <snapshot-name>
```

Start the CT:

```bash
pct start "${WS_CTID}"
```

Validate after rollback:

```bash
./scripts/verify-watchstate.sh --ctid "${WS_CTID}"
```

## Application-Level Restore

Use application-level restore when you want to restore WatchState runtime state from backup archives without rolling back the whole CT.

The restore procedure is documented in:

```text
research/Phase-8-Backup-Restore.md
```

Important command context:

- Run host-side commands from the Proxmox host.
- Commands that use `pct exec <CTID> --` execute inside the target CT.
- Do not run restore-target `groupadd`, `useradd`, `chown`, `tar`, or `systemctl` commands directly on the Proxmox host unless they are wrapped with `pct exec`.

## Failed Update Recovery

If `update-watchstate.sh` fails, it attempts to restart WatchState web/scheduler services before exiting.

After a failed update, run:

```bash
./scripts/verify-watchstate.sh --ctid "${WS_CTID}"
```

If verification passes, capture the error output and decide whether to retry later.

If verification fails, choose one rollback path:

```text
snapshot rollback
application-level restore
manual repair
```

Use snapshot rollback when database migrations may have executed or when the app and `/config` may be out of sync.

Use application-level restore when the CT itself is healthy but WatchState files or data need to return to a known backup.

Use manual repair only when the failure is clearly isolated, for example:

```text
missing rsync
frontend output copy failed
service restart failed
```

## Manual Service Stop and Start

Run from the Proxmox host.

Stop WatchState services:

```bash
pct exec "${WS_CTID}" -- systemctl stop watchstate-scheduler.service
pct exec "${WS_CTID}" -- systemctl stop watchstate-web.service
```

Start WatchState services:

```bash
pct exec "${WS_CTID}" -- systemctl start watchstate-web.service
pct exec "${WS_CTID}" -- systemctl start watchstate-scheduler.service
```

Validate:

```bash
pct exec "${WS_CTID}" -- systemctl is-active redis-server.service watchstate-web.service watchstate-scheduler.service
pct exec "${WS_CTID}" -- curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck
```

## Uninstall Options

There are two uninstall models:

```text
remove the entire CT
remove WatchState from an existing CT
```

For this project, removing the entire CT is the cleanest uninstall path because the CT is dedicated to WatchState.

## Full CT Removal

Run from the Proxmox host.

Create a final backup first:

```bash
./scripts/backup-watchstate.sh --ctid "${WS_CTID}"
```

Stop the CT:

```bash
pct shutdown "${WS_CTID}" --timeout 60 || pct stop "${WS_CTID}"
```

Remove the CT:

```bash
pct destroy "${WS_CTID}"
```

This removes the container. It does not remove host-side backup directories created under `/root/watchstate-backups` or a custom backup root.

## In-Place WatchState Removal

Only use this if the CT contains other workloads that must be preserved.

Run from the Proxmox host.

Stop and disable WatchState services:

```bash
pct exec "${WS_CTID}" -- systemctl disable --now watchstate-scheduler.service watchstate-web.service
```

Remove WatchState service unit files:

```bash
pct exec "${WS_CTID}" -- rm -f /etc/systemd/system/watchstate-web.service /etc/systemd/system/watchstate-scheduler.service
pct exec "${WS_CTID}" -- systemctl daemon-reload
```

Remove WatchState app/runtime paths:

```bash
pct exec "${WS_CTID}" -- rm -rf /opt/app /opt/bin/frankenphp /config
```

Optionally remove the service user and group after confirming nothing else uses them:

```bash
pct exec "${WS_CTID}" -- sh -c 'id watchstate >/dev/null 2>&1 && userdel watchstate || true'
pct exec "${WS_CTID}" -- sh -c 'getent group watchstate >/dev/null 2>&1 && groupdel watchstate || true'
```

Redis was installed as a Debian package for this deployment. Remove it only if the CT does not need Redis for anything else:

```bash
pct exec "${WS_CTID}" -- apt purge -y redis-server redis-tools
pct exec "${WS_CTID}" -- apt autoremove -y
```

## Host-Side Backup Cleanup

List backups:

```bash
./scripts/backup-watchstate.sh --list
```

Dry-run prune:

```bash
./scripts/backup-watchstate.sh --prune-only --prune-dry-run
```

Disable retention pruning:

```bash
./scripts/backup-watchstate.sh --keep 0
```

Delete host-side backup directories manually only after confirming they are no longer needed.

## Validation After Rollback

After any rollback or restore, run:

```bash
./scripts/verify-watchstate.sh --ctid "${WS_CTID}"
```

Expected successful result:

```text
Warnings: 0
Failures: 0
Verification passed.
```

Also confirm the UI is reachable and the configured backend tasks look correct.
