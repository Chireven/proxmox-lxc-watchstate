# Proxmox LXC WatchState

Native WatchState installation notes, scripts, and service definitions for running WatchState directly inside a Proxmox LXC container without Docker.

## What this repo provides

- A validated native WatchState install workflow for Debian-based Proxmox LXC containers.
- Host-side helper scripts for install, backup, update, and verification.
- Native systemd service definitions for the WatchState web service and scheduler.
- Rollback, uninstall, troubleshooting, and operational notes.
- Media-backend integration guidance for API-based Plex/Jellyfin sync validation.

## Design goals

- Keep Docker out of the runtime path.
- Run helper scripts from the Proxmox host.
- Avoid requiring Git or build tools on the Proxmox host.
- Install build/runtime tools inside the target LXC only.
- Keep persistent WatchState state under `/config`.
- Keep WatchState source under `/opt/app`.
- Keep FrankenPHP under `/opt/bin/frankenphp`.

## Quick start

Create a clean Debian LXC container, then run these commands on the Proxmox host:

```bash
mkdir -p /scripts/watchstate
cd /scripts/watchstate

curl -fsSL \
  https://raw.githubusercontent.com/Chireven/proxmox-lxc-watchstate/main/scripts/install-watchstate.sh \
  -o install-watchstate.sh

curl -fsSL \
  https://raw.githubusercontent.com/Chireven/proxmox-lxc-watchstate/main/scripts/verify-watchstate.sh \
  -o verify-watchstate.sh

curl -fsSL \
  https://raw.githubusercontent.com/Chireven/proxmox-lxc-watchstate/main/scripts/update-watchstate.sh \
  -o update-watchstate.sh

curl -fsSL \
  https://raw.githubusercontent.com/Chireven/proxmox-lxc-watchstate/main/scripts/backup-watchstate.sh \
  -o backup-watchstate.sh

chmod 0755 *.sh
```

Install into an existing running CT:

```bash
./install-watchstate.sh --ctid 104
```

Verify:

```bash
./verify-watchstate.sh --ctid 104
```

Update later:

```bash
./update-watchstate.sh --ctid 104
```

Back up:

```bash
./backup-watchstate.sh --ctid 104
```

See [docs/INSTALL.md](docs/INSTALL.md) for the full validated install and operations workflow.

See [docs/MEDIA.md](docs/MEDIA.md) for Phase 7 media-backend integration guidance covering API connectivity, two-Plex watched-state sync validation, optional path matching, and why media bind mounts are not required by default.

## Validated runtime layout

Inside the WatchState CT:

```text
/opt/app              WatchState source tree
/config               Persistent WatchState config and data
/opt/bin/frankenphp   FrankenPHP static binary
/usr/local/bin/bun    Bun frontend tool
```

Native services:

```text
redis-server.service
watchstate-web.service
watchstate-scheduler.service
```

Healthcheck:

```text
http://127.0.0.1:8080/v1/api/system/healthcheck
```

## Repository layout

```text
.
├── docs/       Polished installation and operations documentation
├── examples/   Sample configuration files and templates
├── notes/      Project journal and working notes
├── research/   Upstream WatchState analysis
├── scripts/    Installer, updater, backup, and verification scripts
├── systemd/    Native service definitions
└── tests/      Manual and automated validation notes
```

## Project status

The install, backup, update, and verification scripts have been validated against a native WatchState LXC deployment. See [PROJECT.md](PROJECT.md) for project history and remaining optional workstreams.

## Public repository safety

Do not commit generated backup archives, copied runtime data, logs containing private data, database files, private URLs, or host-specific configuration.
