# Phase 9 - Update Procedure

This document defines the native source update procedure for the validated WatchState LXC installation.

## Current Validated Layout

Runtime target:

```text
CT: 103
hostname: watchstate
service user: watchstate
service group: watchstate
```

Application paths:

```text
/opt/app                  WatchState source tree
/opt/app/frontend         Nuxt frontend source
/opt/app/frontend/exported generated frontend output
/opt/app/public/exported  frontend output served by FrankenPHP
/config                   persistent WatchState runtime data
```

Systemd services:

```text
redis-server.service
watchstate-web.service
watchstate-scheduler.service
```

Validated baseline before update testing:

```text
branch: master
commit: 9a4c8225e3d9502ae759b74fe301ae5d52df7c54
remote: https://github.com/arabcoders/watchstate.git
FrankenPHP: v1.12.4
runtime PHP: 8.5.8
Composer: 2.8.8
Composer PHP: Debian PHP 8.4.23
Bun: 1.3.14
```

## Required Update Prerequisites

The container must have these tools available:

```text
git
composer
bun
rsync
/opt/bin/frankenphp
```

`rsync` is required because the frontend build output is generated under `/opt/app/frontend/exported`, while the web service serves `/opt/app/public/exported`.

Install `rsync` if missing:

```bash
pct exec 103 -- apt update
pct exec 103 -- apt install -y rsync
```

## Important Update Findings

Git repository commands should be run as the `watchstate` user because `/opt/app` is owned by `watchstate`. Do not work around Git ownership checks by adding `/opt/app` as a root global safe directory.

```bash
pct exec 103 -- runuser -u watchstate -- sh -c 'cd /opt/app && git status --short'
```

The generated frontend output is untracked and appears in `git status` as:

```text
?? public/exported/
```

This is expected for the native install.

The validated frontend generation command is:

```bash
composer frontend:gen
```

This runs:

```text
bun --cwd=./frontend/ generate
```

After generation, copy the output into the served public path:

```bash
rsync -a --delete frontend/exported/ public/exported/
```

Database migrations are dry-run/report mode unless `--execute` is supplied. Do not use plain `db:migrate` as the actual update migration command.

Use:

```bash
/opt/bin/frankenphp php-cli bin/console db:migrate --execute --no-interaction
```

## Pre-Update Backup and Snapshot

Run from the Proxmox host.

Set the target CT:

```bash
WS_CTID=103
```

Create an application-level backup:

```bash
/scripts/backups/backup-watchstate.sh --ctid "${WS_CTID}"
```

Create a Proxmox snapshot:

```bash
pct snapshot "${WS_CTID}" watchstate-pre-update-YYYYMMDD --description "Pre-update WatchState snapshot"
```

## Validated Update Procedure

Run from the Proxmox host.

```bash
WS_CTID=103
```

Stop WatchState services before modifying application files or the database:

```bash
pct exec "${WS_CTID}" -- systemctl stop watchstate-scheduler.service
pct exec "${WS_CTID}" -- systemctl stop watchstate-web.service
```

Run the source update, dependency refresh, frontend generation, frontend copy, and database maintenance as the `watchstate` user:

```bash
pct exec "${WS_CTID}" -- runuser -u watchstate -- sh -c '
set -e
cd /opt/app

git fetch origin
git status --short
git pull --ff-only origin master

composer install --no-dev --prefer-dist --optimize-autoloader

bun --cwd=./frontend install --frozen-lockfile
composer frontend:gen

rm -rf public/exported
mkdir -p public/exported
rsync -a --delete frontend/exported/ public/exported/

/opt/bin/frankenphp php-cli bin/console db:migrate --execute --no-interaction
/opt/bin/frankenphp php-cli bin/console db:index
/opt/bin/frankenphp php-cli bin/console events:cache
'
```

Start services:

```bash
pct exec "${WS_CTID}" -- systemctl start watchstate-web.service
pct exec "${WS_CTID}" -- systemctl start watchstate-scheduler.service
```

Validate services and healthcheck:

```bash
pct exec "${WS_CTID}" -- systemctl is-active redis-server.service watchstate-web.service watchstate-scheduler.service
pct exec "${WS_CTID}" -- curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck
```

Expected result:

```text
active
active
active
{"status":"ok","message":"System is healthy"}
```

Validate frontend output exists:

```bash
pct exec "${WS_CTID}" -- runuser -u watchstate -- sh -c 'du -sh /opt/app/public/exported && find /opt/app/public/exported -maxdepth 1 -type f -o -type d | head'
```

## Rollback Procedure

If the update fails before service restart, do not keep retrying blindly.

First capture the immediate error output, then choose one rollback path:

1. Restore the Proxmox snapshot taken immediately before the update.
2. Restore the application-level backup using the Phase 8 restore procedure.
3. If only frontend copy failed and source/database changes are otherwise valid, repair the frontend copy step after installing missing prerequisites such as `rsync`.

For snapshot rollback from the Proxmox host, use the appropriate Proxmox rollback command for the snapshot that was created before the update.

## Validation Result

The no-op update procedure was validated against CT 103 while already current with upstream `origin/master`.

Validated corrections discovered during testing:

```text
rsync must be installed in the container.
plain db:migrate is dry-run/report mode.
db:migrate --execute --no-interaction is required for actual migrations.
```

Final validation after correction:

```text
redis-server.service: active
watchstate-web.service: active
watchstate-scheduler.service: active
healthcheck: healthy
/opt/app/public/exported: populated
```
