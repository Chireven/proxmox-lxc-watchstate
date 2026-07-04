# Phase 3 - Native Prerequisites

This phase installs and validates the native runtime prerequisites for WatchState inside the Debian 13 LXC baseline.

## Goals

- Install only packages with a known purpose.
- Validate versions before installing WatchState itself.
- Keep the container clean and snapshot-friendly.
- Avoid application configuration until the runtime layer is understood.

## Known Requirements

From upstream analysis:

- Debian 13 base
- PHP 8.4 compatible runtime
- Composer for PHP dependencies
- Bun for frontend asset generation
- SQLite for local database storage
- Redis for cache support
- FFmpeg and FFprobe for media support
- curl and CA certificates for HTTP/API communication
- font packages and fontconfig, matching the upstream container assumptions

## First Install Group

The first package group should cover operating system utilities and non-PHP runtime tools:

- git
- curl
- ca-certificates
- unzip
- sqlite3
- redis-server
- ffmpeg
- gettext-base
- fontconfig
- fonts-freefont-ttf
- fonts-noto
- fonts-terminus
- fonts-dejavu
- procps
- net-tools
- iproute2
- tzdata

## Deferred Items

Do not install these until the next validation step:

- FrankenPHP
- Composer
- Bun
- WatchState source
- systemd service files

## Validation

After installing the first package group, validate:

```bash
sqlite3 --version
redis-server --version
ffmpeg -version
ffprobe -version
git --version
curl --version
fc-list | head
systemctl status redis-server --no-pager
```

## Snapshot Point

After this phase validates cleanly, create a Proxmox snapshot before installing WatchState source or modifying service configuration.
