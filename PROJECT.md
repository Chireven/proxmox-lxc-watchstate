# Project Roadmap

This project documents and automates a native WatchState installation for Proxmox LXC.

## Public Repository Safety

This repository is public. Do not commit secrets or private deployment data. Use placeholders for tokens, passwords, internal URLs, private keys, certificates, real application config, database files, and logs that may contain sensitive values.

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

- [ ] Install required OS packages.
- [ ] Install PHP/runtime dependencies.
- [ ] Install Composer dependencies.
- [ ] Install frontend build dependencies if required.
- [ ] Verify dependency versions.

## Phase 4 - Application Installation

- [ ] Clone WatchState source.
- [ ] Build application assets.
- [ ] Configure environment.
- [ ] Initialize storage.
- [ ] Start application manually.

## Phase 5 - Native Service Management

- [ ] Create systemd unit.
- [ ] Configure service user and permissions.
- [ ] Enable service startup.
- [ ] Validate restart behavior.

## Phase 6 - Application Configuration

- [ ] Complete first web login.
- [ ] Configure WatchState from UI.
- [ ] Enable scheduled tasks from UI.
- [ ] Confirm no manual cron is required.

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

## Current Next Step

Begin Phase 3 by installing and validating the native prerequisite packages for WatchState.
