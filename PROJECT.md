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

## Phase 7 - Media Backend Integration

- [x] Document that media bind mounts are not required by default.
- [x] Document API-based Plex/Jellyfin media-backend integration model.
- [x] Document optional path matching behavior.
- [x] Validate Plex/Jellyfin backend connectivity.
- [x] Add sanitized verifier support-bundle mode for backend topology diagnostics.
- [x] Add inferred identity sync relationship diagnostics to support-bundle mode.
- [x] Validate sanitized support-bundle output on a rebuilt production container.
- [ ] Validate watched-state import from Plex server A.
- [ ] Validate watched-state export/sync to Plex server B.
- [ ] Validate reverse direction if bidirectional sync is intended.
- [ ] Review unmatched or mismatched items.
- [ ] Snapshot validated Phase 7 API sync configuration.

## Phase 8 - Operations

- [x] Write backup procedure.
- [x] Produce backup script.
- [x] Validate backup script.
- [x] Add backup listing and retention.
- [x] Validate restore into a clean scratch container.
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
- [x] Rebuild production using only standalone helper scripts from the repository.

## Current State

WatchState has been validated as a native Debian LXC deployment. The production container was torn down and rebuilt successfully using only the standalone helper scripts downloaded from this repository into `/scripts/watchstate`; the full repository was not required on the Proxmox host.

The rebuilt production container is reported healthy and running normally. Composer dependencies are installed, frontend assets are built, the application has been initialized, Redis is running, FrankenPHP is installed, and both native WatchState services are expected to be enabled and running.

Two Plex backends have been configured from the WatchState UI. The sanitized support bundle confirms both backends are reachable, both have import enabled, both currently have export disabled, and both share the same sanitized identity mapping. Aggregate database statistics confirm imported WatchState state exists for one backend without exposing media titles, paths, users, backend names, or tokens.

Cron validation found no crontab for the WatchState service user and no WatchState-specific cron entries in the standard cron directories. The scheduler is handled by the enabled and running `watchstate-scheduler.service` unit.

Backup and restore operations are validated. The host-side backup script creates archives for `/config`, native service units, FrankenPHP, and the app tree. A clean scratch container restore was validated successfully and then removed. The backup script supports CT name discovery, backup listing, prune-only mode, dry-run pruning, and count-based retention with a default of 14 timestamp-style backup directories.

The native update procedure is validated. Required corrections discovered during testing are documented: `rsync` must be installed, frontend output must be synced from `/opt/app/frontend/exported` to `/opt/app/public/exported`, database migrations must use `db:migrate --execute --no-interaction`, and update-time frontend generation must use `/usr/local/bin/bun` or export a PATH that includes `/usr/local/bin`.

The verification script is produced and validated. It supports CT name discovery and checks host/container state, service health, runtime dependencies, source state, database presence, migration dry-run status, frontend output, and optional sanitized backend support-bundle output. Support-bundle mode reports sanitized backend topology, aggregate state statistics, and inferred same-identity sync relationships. Verification output is color-coded for easier review and includes a compact final pass/warning/failure summary.

The update script is produced and validated. It successfully performed CT name discovery, pre-update backup, retention check, Proxmox snapshot creation, source/dependency/frontend update steps, migration check, service restart, healthcheck validation, and post-update verification. The script handles Bun installed at `/usr/local/bin/bun`.

The install script is produced and validated against clean scratch and production containers. Validation confirmed that the script works as a standalone Proxmox-host helper from `/scripts/watchstate` without requiring the full repository layout on the host. Important validation fixes included embedded systemd service units, direct FrankenPHP static binary installation from GitHub releases, explicit Bun path handling, PATH export for Composer frontend generation, and pre-created `/opt/app` ownership for the `watchstate` service user.

Rollback and uninstall notes are documented. The preferred rollback path is Proxmox snapshot rollback for full CT recovery, followed by application-level restore from backup archives when only WatchState state needs recovery. Full CT removal is the preferred uninstall path for this dedicated deployment.

The troubleshooting guide is documented. It covers service health, web/scheduler issues, Redis, permissions, Git ownership, update failures, frontend output, backup/restore issues, snapshot handling, locale warnings, and final verification.

Phase 7 media-backend integration documentation has been corrected. The media guide treats WatchState as an API-based watched-state sync application. Media bind mounts are documented as optional troubleshooting-only mounts, not as a required part of normal WatchState operation. Live validation focuses on watched-state import/export behavior between Plex backends. The verifier support-bundle mode provides sanitized backend topology plus aggregate state statistics.

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

Enable export for the intended target backend or both backends, run an import for the second backend so aggregate state exists for both sides, then use the sanitized support bundle to guide watched-state import/export validation between Plex backends.
