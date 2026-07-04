# Project Roadmap

This project documents and automates a native WatchState installation for Proxmox LXC.

## Public Repository Safety

This repository is public. Do not commit secrets or private deployment data. Use placeholders for tokens, passwords, internal URLs, private keys, certificates, real application config, database files, and logs that may contain sensitive values.

Never print, copy, or commit the live contents of `/config/config/.env`, `/config/config/servers.yaml` after real servers are added, `/config/db/watchstate_v02.db`, certificates, private keys, API keys, logs, or private hostnames/URLs.

## Phase 0 - Project Foundation

- [x] Create GitHub repository.
- [x] Bootstrap initial README.
- [x] Create repository structure.
- [x] Establish initial project documentation.

## Phase 1 - Upstream Analysis

- [x] Review upstream Dockerfile.
- [x] Review upstream compose examples.
- [x] Identify build-time dependencies.
- [x] Identify runtime dependencies.
- [x] Identify persistent storage paths.
- [x] Identify scheduler behavior.
- [x] Identify update assumptions.
- [x] Draft native runtime blueprint.

## Phase 2 - LXC Baseline

- [x] Create fresh Debian LXC.
- [x] Confirm container settings.
- [x] Update operating system.
- [x] Snapshot clean baseline.

## Phase 3 - Native Prerequisites

- [x] Install required OS packages.
- [x] Install PHP/runtime dependencies.
- [x] Install Composer dependencies.
- [x] Install frontend build dependencies if required.
- [x] Verify dependency versions.
- [x] Create dedicated service user.
- [x] Create upstream-aligned directory layout.
- [x] Snapshot validated prerequisite state.

## Phase 4 - Application Installation

- [x] Clone WatchState source.
- [x] Build application assets.
- [x] Configure environment.
- [x] Initialize storage.
- [x] Start application manually.

## Phase 5 - Native Service Management

- [x] Install and validate FrankenPHP.
- [x] Create `watchstate-web.service`.
- [x] Create `watchstate-scheduler.service`.
- [x] Configure service user and permissions.
- [x] Enable service startup.
- [x] Validate restart behavior.
- [x] Reboot-validate native services.
- [x] Validate healthcheck through systemd-managed FrankenPHP service.

## Phase 6 - Application Configuration

- [x] Confirm latest Proxmox snapshot after service validation.
- [x] Complete first web login.
- [ ] Configure WatchState from UI.
- [ ] Enable scheduled tasks from UI.
- [ ] Confirm no manual cron is required.
- [ ] Decide whether Debian `redis-server` remains the supported native Redis model.

## Phase 7 - Media Integration

- [ ] Add Proxmox bind mounts after app is healthy.
- [ ] Verify read-only/read-write requirements.
- [ ] Validate Plex/Jellyfin connectivity.
- [ ] Validate library scan behavior.

## Phase 8 - Operations

- [ ] Write backup procedure.
- [ ] Write update procedure.
- [ ] Write uninstall/rollback notes.
- [ ] Write troubleshooting guide.
- [ ] Produce install script.
- [ ] Produce update script.
- [ ] Produce verification script.

## Current State

WatchState is installed natively in Debian LXC CT 103 with persistent runtime data under `/config`. Composer dependencies are installed, frontend assets are built and copied to `/opt/app/public/exported`, the application has been initialized, the SQLite database has been created and migrated, Debian Redis responds to `PONG`, FrankenPHP is installed at `/opt/bin/frankenphp`, and both native WatchState services are enabled, running, and reboot-validated. The post-service snapshot exists and first web login has been completed.

Current validated services:

- `watchstate-web.service`
- `watchstate-scheduler.service`
- `redis-server.service`

Validated healthcheck:

```text
http://127.0.0.1:8080/v1/api/system/healthcheck
```

Known safe snapshot checkpoint before service creation:

```text
watchstate-phase-5-frankenphp-validated
```

Confirmed snapshot checkpoint after service validation:

```text
watchstate-phase-5-services-validated
```

## Current Next Step

Continue Phase 6 by configuring WatchState from the UI. Confirm scheduled tasks are enabled inside WatchState and that no manually managed cron jobs are required.
