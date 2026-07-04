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

The first package group covers operating system utilities and non-PHP runtime tools:

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

## Validation Result

Validated successfully on the Debian 13 LXC baseline.

Observed versions:

| Tool | Version |
| --- | --- |
| SQLite | 3.46.1 |
| Redis | 8.0.2 |
| FFmpeg | 7.1.5-0+deb13u1 |
| FFprobe | 7.1.5-0+deb13u1 |
| Git | 2.47.3 |
| curl | 8.14.1-2+deb13u3 |

Redis service status:

- `redis-server.service` enabled
- `redis-server.service` active and running
- Listening on `127.0.0.1:6379`

Fontconfig validation succeeded with fonts visible through `fc-list`.

## Deferred Items

Do not install these until the next validation step:

- FrankenPHP
- Composer
- Bun
- WatchState source
- systemd service files

## Snapshot Point

After the full prerequisite phase validates cleanly, create a Proxmox snapshot before installing WatchState source or modifying service configuration.

## Next Step

Validate the PHP runtime path. WatchState requires PHP 8.4 and specific extensions. The next decision is whether to use standalone FrankenPHP as the PHP runtime, matching upstream, or Debian PHP packages plus a traditional web server.
