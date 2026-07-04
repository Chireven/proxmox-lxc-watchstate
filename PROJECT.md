# Project Roadmap

This project documents and automates a native WatchState installation for Proxmox LXC.

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
- [ ] Identify update assumptions.
- [x] Draft native runtime blueprint.

## Phase 2 - LXC Baseline

- [ ] Create fresh Debian LXC.
- [ ] Confirm container settings.
- [ ] Update operating system.
- [ ] Snapshot clean baseline.

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

Finish Phase 1 by documenting update assumptions, then move to Phase 2 and create the fresh Debian LXC baseline.
