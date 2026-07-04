# Architecture

This document will describe the target native WatchState architecture for Proxmox LXC.

## Goals

- Run WatchState directly in a Debian-based LXC container.
- Avoid Docker as the runtime.
- Preserve the behavior expected by the upstream application.
- Keep persistent state, services, and upgrades understandable.

## Components to Analyze

- WatchState application source
- PHP runtime
- FrankenPHP or alternative web runtime
- Composer dependencies
- Frontend build tooling
- SQLite storage
- Redis, if required
- FFmpeg/FFprobe
- Scheduler behavior
- Persistent configuration directory

## Open Questions

- Which dependencies are runtime requirements versus build-time only?
- Is Redis mandatory or optional?
- Can the standalone FrankenPHP binary be used cleanly in LXC?
- Which environment variables are required for a native deployment?
- How should upgrades be handled safely?
