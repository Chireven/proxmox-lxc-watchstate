# Phase 11 - Troubleshooting Guide

This document collects troubleshooting checks for the native WatchState LXC deployment.

## Scope

Validated target:

```text
Proxmox LXC
Debian container
native WatchState source install
FrankenPHP web service
systemd scheduler service
Debian redis-server
```

Main paths:

```text
/opt/app                  WatchState source tree
/opt/bin/frankenphp        FrankenPHP binary
/config                   persistent WatchState runtime data
/opt/app/frontend/exported generated frontend output
/opt/app/public/exported  frontend output served by FrankenPHP
```

Systemd services:

```text
redis-server.service
watchstate-web.service
watchstate-scheduler.service
```

## Start With Verification

Run from the Proxmox host:

```bash
./scripts/verify-watchstate.sh
```

Or explicitly:

```bash
./scripts/verify-watchstate.sh --ctid 103
```

The verification script checks the common failure points:

```text
container state
service user/group
required paths
ownership
systemd services
FrankenPHP
Redis
healthcheck
Git state
tool availability
Composer platform requirements
database presence
migration dry-run
frontend output
```

Expected summary:

```text
Warnings: 0
Failures: 0
Verification passed.
```

## Service Health Checks

Run from the Proxmox host:

```bash
WS_CTID=103
pct exec "${WS_CTID}" -- systemctl is-active redis-server.service watchstate-web.service watchstate-scheduler.service
pct exec "${WS_CTID}" -- curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck
```

Expected:

```text
active
active
active
{"status":"ok","message":"System is healthy"}
```

Read logs:

```bash
pct exec "${WS_CTID}" -- journalctl -u watchstate-web.service -n 100 --no-pager
pct exec "${WS_CTID}" -- journalctl -u watchstate-scheduler.service -n 100 --no-pager
pct exec "${WS_CTID}" -- journalctl -u redis-server.service -n 100 --no-pager
```

## Web Service Is Not Healthy

Symptoms:

```text
watchstate-web.service is inactive or failed
healthcheck fails
browser cannot reach the app
```

Checks:

```bash
pct exec "${WS_CTID}" -- systemctl status watchstate-web.service --no-pager
pct exec "${WS_CTID}" -- journalctl -u watchstate-web.service -n 100 --no-pager
pct exec "${WS_CTID}" -- ss -ltnp | grep ':8080' || true
pct exec "${WS_CTID}" -- /opt/bin/frankenphp --version
pct exec "${WS_CTID}" -- ls -ld /opt/app /opt/app/public /opt/app/public/exported /config
```

Common causes:

```text
FrankenPHP missing or not executable
/opt/app missing
/config missing
wrong ownership on /opt/app or /config
port 8080 already in use
service unit changed or not reloaded
```

Typical repair:

```bash
pct exec "${WS_CTID}" -- chown -R watchstate:watchstate /config /opt/app
pct exec "${WS_CTID}" -- systemctl daemon-reload
pct exec "${WS_CTID}" -- systemctl restart watchstate-web.service
pct exec "${WS_CTID}" -- curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck
```

## Scheduler Is Not Running

Symptoms:

```text
scheduled jobs do not run
UI tasks do not execute automatically
watchstate-scheduler.service is inactive or failed
```

Checks:

```bash
pct exec "${WS_CTID}" -- systemctl status watchstate-scheduler.service --no-pager
pct exec "${WS_CTID}" -- journalctl -u watchstate-scheduler.service -n 100 --no-pager
pct exec "${WS_CTID}" -- ps aux | grep -E 'system:scheduler|frankenphp' | grep -v grep || true
```

Important note:

```text
No manual cron is required for this deployment.
The scheduler is handled by watchstate-scheduler.service.
```

Typical repair:

```bash
pct exec "${WS_CTID}" -- systemctl daemon-reload
pct exec "${WS_CTID}" -- systemctl restart watchstate-scheduler.service
pct exec "${WS_CTID}" -- systemctl is-active watchstate-scheduler.service
```

## Redis Problems

Symptoms:

```text
Redis ping fails
healthcheck fails
services start but app behaves incorrectly
```

Checks:

```bash
pct exec "${WS_CTID}" -- systemctl status redis-server.service --no-pager
pct exec "${WS_CTID}" -- journalctl -u redis-server.service -n 100 --no-pager
pct exec "${WS_CTID}" -- redis-cli ping
pct exec "${WS_CTID}" -- ss -ltnp | grep ':6379' || true
```

Expected Redis ping:

```text
PONG
```

Typical repair:

```bash
pct exec "${WS_CTID}" -- systemctl enable --now redis-server.service
pct exec "${WS_CTID}" -- redis-cli ping
```

## Permission Problems

Symptoms:

```text
app cannot write state
updates fail
backup/restore produces service failures
healthcheck fails after restore
```

Checks:

```bash
pct exec "${WS_CTID}" -- id watchstate
pct exec "${WS_CTID}" -- getent group watchstate
pct exec "${WS_CTID}" -- stat -c '%U:%G %n' /config /opt/app
pct exec "${WS_CTID}" -- find /config /opt/app -maxdepth 2 \! -user watchstate -o \! -group watchstate | head -50
```

Typical repair:

```bash
pct exec "${WS_CTID}" -- chown -R watchstate:watchstate /config /opt/app
pct exec "${WS_CTID}" -- systemctl restart watchstate-web.service watchstate-scheduler.service
```

Important command context:

```text
Run user/group/ownership repair commands inside the CT using pct exec.
Do not run restore-target chown/useradd/groupadd commands directly on the Proxmox host.
```

## Git Ownership or Dubious Ownership Errors

Symptom:

```text
fatal: detected dubious ownership in repository at '/opt/app'
```

Cause:

```text
The repository is owned by watchstate, but Git was run as root.
```

Preferred fix:

```bash
pct exec "${WS_CTID}" -- runuser -u watchstate -- sh -c 'cd /opt/app && git status --short'
```

Do not work around this by adding `/opt/app` as a root global safe directory unless there is a specific reason.

## Update Problems

Start with:

```bash
./scripts/update-watchstate.sh
```

If it fails, the script attempts to restart WatchState web/scheduler services before exiting.

Post-failure check:

```bash
./scripts/verify-watchstate.sh --ctid "${WS_CTID}"
```

Common update failures:

```text
missing rsync
Composer platform requirement failure
Bun install/generate failure
frontend output copy failure
migration command failure
service restart failure
```

`rsync` is required:

```bash
pct exec "${WS_CTID}" -- apt update
pct exec "${WS_CTID}" -- apt install -y rsync
```

Frontend output must be copied from generated output to served output:

```bash
pct exec "${WS_CTID}" -- runuser -u watchstate -- sh -c 'cd /opt/app && rsync -a --delete frontend/exported/ public/exported/'
```

Database migrations must use `--execute` to apply changes:

```bash
pct exec "${WS_CTID}" -- runuser -u watchstate -- sh -c 'cd /opt/app && /opt/bin/frankenphp php-cli bin/console db:migrate --execute --no-interaction'
```

Plain `db:migrate` is useful as a dry-run/status check:

```bash
pct exec "${WS_CTID}" -- runuser -u watchstate -- sh -c 'cd /opt/app && /opt/bin/frankenphp php-cli bin/console db:migrate --no-interaction'
```

## Frontend Output Problems

Symptoms:

```text
healthcheck works but UI assets/pages are missing
public/exported is missing or empty
update script fails near rsync
```

Checks:

```bash
pct exec "${WS_CTID}" -- runuser -u watchstate -- sh -c 'du -sh /opt/app/frontend/exported /opt/app/public/exported 2>/dev/null || true'
pct exec "${WS_CTID}" -- runuser -u watchstate -- sh -c 'cd /opt/app && git status --short'
```

Repair:

```bash
pct exec "${WS_CTID}" -- runuser -u watchstate -- sh -c '
set -e
cd /opt/app
bun --cwd=./frontend install --frozen-lockfile
composer frontend:gen
rm -rf public/exported
mkdir -p public/exported
rsync -a --delete frontend/exported/ public/exported/
'

pct exec "${WS_CTID}" -- systemctl restart watchstate-web.service
```

Expected Git status may include:

```text
?? public/exported/
```

That is expected because `public/exported` is generated output.

## Backup Problems

List backups:

```bash
./scripts/backup-watchstate.sh --list
```

Run a quick backup without `/opt/app`:

```bash
./scripts/backup-watchstate.sh --no-app
```

Dry-run retention pruning:

```bash
./scripts/backup-watchstate.sh --prune-only --prune-dry-run
```

Common backup failures:

```text
pct not available because script was not run on Proxmox host
CT not running
CT name not found
permissions problem creating backup root
tar failure due to missing paths
service restart failure after backup
```

The backup script discovers a CT named `watchstate` by default. Override with:

```bash
./scripts/backup-watchstate.sh --ctid 103
./scripts/backup-watchstate.sh --name watchstate
```

## Restore Problems

Common restore mistakes:

```text
running groupadd/useradd/chown on the Proxmox host instead of inside the CT
forgetting systemctl daemon-reload after restoring unit files
missing watchstate user/group in a scratch CT
wrong ownership on /config or /opt/app
assuming pct exec expands wildcards without a shell
```

Wildcard note:

```bash
pct exec "${WS_CTID}" -- sh -c 'ls -lh /tmp/watchstate-*.tgz'
```

Do not use this form when a wildcard must expand:

```bash
pct exec "${WS_CTID}" -- ls -lh /tmp/watchstate-*.tgz
```

## Snapshot Problems

List snapshots:

```bash
pct listsnapshot "${WS_CTID}"
```

Create snapshot:

```bash
pct snapshot "${WS_CTID}" watchstate-before-change-YYYYMMDD --description "WatchState checkpoint before change"
```

Rollback is documented in:

```text
research/Phase-10-Rollback-Uninstall.md
```

## Locale Warnings

Minimal Debian containers may show locale warnings during package operations.

Observed locale warnings did not block validation. If cleanup is desired:

```bash
pct exec "${WS_CTID}" -- apt install -y locales
pct exec "${WS_CTID}" -- sh -c 'sed -i "s/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen && locale-gen'
```

## Final Validation

After any repair, run:

```bash
./scripts/verify-watchstate.sh --ctid "${WS_CTID}"
```

Expected:

```text
Warnings: 0
Failures: 0
Verification passed.
```
