# Project Roadmap

This project documents and automates a native WatchState installation for Proxmox LXC.

## Public Repository Safety

This repository is public. Keep deployment-specific runtime data out of version control and use placeholders in documentation.

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
- [x] Configure WatchState from UI.
- [x] Enable scheduled tasks from UI.
- [x] Confirm no manual cron is required.
- [x] Decide whether Debian `redis-server` remains the supported native Redis model.
- [x] Snapshot validated Phase 6 application configuration.

## Phase 7 - Media Integration

- [ ] Add Proxmox bind mounts after app is healthy.
- [ ] Verify read-only/read-write requirements.
- [x] Validate Plex/Jellyfin connectivity.
- [ ] Validate library scan behavior.

## Phase 8 - Operations

- [x] Write backup procedure.
- [x] Produce backup script.
- [x] Validate backup script.
- [x] Add backup listing and retention.
- [x] Validate restore into a clean scratch CT.
- [x] Write update procedure.
- [x] Validate update procedure.
- [x] Produce verification script.
- [x] Validate verification script.
- [x] Produce update script.
- [x] Validate update script.
- [x] Write uninstall/rollback notes.
- [x] Write troubleshooting guide.
- [x] Produce install script.
- [x] Validate install script.

## Current State

WatchState is installed natively in Debian LXC CT 103. Composer dependencies are installed, frontend assets are built, the application has been initialized, Redis responds to PONG, FrankenPHP is installed, and both native WatchState services are enabled, running, and reboot-validated. The post-service snapshot exists and first web login has been completed.

Two Plex backends have been configured from the WatchState UI. Backup and Import jobs were created for both backends and completed successfully. Import and Export tasks are visible in the UI and enabled.

Cron validation found no crontab for the WatchState service user and no WatchState-specific cron entries in the standard cron directories. The scheduler is handled by the enabled and running `watchstate-scheduler.service` unit.

Backup and restore operations are validated. The host-side backup script creates archives for `/config`, native service units, FrankenPHP, and the app tree. A clean scratch CT restore was validated successfully and then removed. The backup script now supports CT name discovery, backup listing, prune-only mode, dry-run pruning, and count-based retention with a default of 14 timestamp-style backup directories.

The native update procedure is validated. Required corrections discovered during testing are documented: `rsync` must be installed, frontend output must be synced from `/opt/app/frontend/exported` to `/opt/app/public/exported`, database migrations must use `db:migrate --execute --no-interaction`, and update-time frontend generation must use `/usr/local/bin/bun` or export a PATH that includes `/usr/local/bin`.

The verification script is produced and validated. It supports CT name discovery and checks host/container state, service health, runtime dependencies, Git state, database presence, migration dry-run status, and frontend output. Verification output is color-coded for easier review and includes a compact final pass/warning/failure summary.

The update script is produced and validated. It successfully performed CT name discovery, pre-update backup, retention check, Proxmox snapshot creation, source/dependency/frontend update steps, migration check, service restart, healthcheck validation, and post-update verification. The script now handles Bun installed at `/usr/local/bin/bun`.

The install script is produced and validated against clean scratch CT 104. Validation confirmed that the script works as a standalone Proxmox-host helper from `/scripts/watchstate` without requiring the full repository layout on the host. Important validation fixes included embedded systemd service units, direct FrankenPHP static binary installation from GitHub releases, explicit Bun path handling, PATH export for Composer frontend generation, and pre-created `/opt/app` ownership for the `watchstate` service user.

Rollback and uninstall notes are documented. The preferred rollback path is Proxmox snapshot rollback for full CT recovery, followed by application-level restore from backup archives when only WatchState state needs recovery. Full CT removal is the preferred uninstall path for this dedicated deployment.

The troubleshooting guide is documented. It covers service health, web/scheduler issues, Redis, permissions, Git ownership, update failures, frontend output, backup/restore issues, snapshot handling, locale warnings, and final verification.

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

Confirmed snapshot checkpoint after Phase 6 application configuration:

```text
watchstate-phase-6-app-configured
```

Confirmed snapshot checkpoint before update validation:

```text
watchstate-pre-update-validation
```

## Current Next Step

Choose the next workstream: final user-facing install documentation, media bind-mount validation, reverse proxy/TLS documentation, or production cutover checklist for CT 103.
