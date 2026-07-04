# Native Runtime Blueprint

This document describes the first-pass native LXC runtime model for WatchState.

## Target Base

- Proxmox LXC
- Debian 13
- Dedicated container for WatchState
- No Docker runtime
- No media bind mounts until the web application is healthy

## Directory Layout

Initial layout should stay close to the upstream container:

```text
/opt/app       WatchState application source
/opt/bin       Helper commands and runtime binaries
/opt/config    Runtime configuration files managed outside the app source
/config        Persistent WatchState data
```

Expected persistent subdirectories:

```text
/config/backup
/config/cache
/config/config
/config/db
/config/debug
/config/logs
/config/webhooks
/config/profiler
```

## Process Model

The upstream container effectively runs three things:

1. Web application runtime
2. Local Redis cache
3. WatchState scheduler loop

For native LXC, these should become system-managed services instead of a Docker entrypoint.

## Proposed Services

### watchstate-web.service

Runs the WatchState web application using FrankenPHP.

Initial target command:

```text
frankenphp php-server --listen 0.0.0.0:8080 --root /opt/app/public
```

### watchstate-scheduler.service

Runs the scheduler loop equivalent to the upstream runner script.

Conceptual behavior:

```text
while true; do
    console system:scheduler --pid-file /tmp/ws-job-runner.pid
    sleep 60
done
```

### redis-server.service

Use local Redis first. The upstream container starts Redis by default and stores cache persistence under `/config/cache`.

Open decision: use the Debian Redis service with adjusted config, or define a WatchState-specific Redis unit using the upstream config.

## Startup Sequence

The native installation must reproduce the important initialization behavior from the upstream entrypoint:

1. Confirm the data path is writable.
2. Load `/config/config/.env` if present.
3. Generate application config structure.
4. Start or verify Redis.
5. Cache routes.
6. Cache event listeners.
7. Run legacy database import if needed.
8. Run database migrations.
9. Run database maintenance.
10. Ensure indexes.
11. Ensure API key exists.
12. Start scheduler.
13. Start web runtime.

## Initial Decisions

| Topic | Decision | Reason |
| --- | --- | --- |
| Base OS | Debian 13 | Matches upstream image. |
| Runtime | FrankenPHP first | Matches upstream behavior. |
| Data path | `/config` | Matches upstream docs and volume path. |
| Application path | `/opt/app` | Matches upstream image. |
| Cache | Local Redis first | Matches upstream default. |
| Scheduler | Managed service | Avoid manual cron edits. |
| Frontend build | Bun during install/update | Matches upstream build stage. |
| PHP dependencies | Composer during install/update | Required by upstream project. |

## Open Questions

- Should Redis use Debian defaults or WatchState-specific config?
- Should the scheduler be one long-running service or a systemd timer every minute?
- Can the standalone FrankenPHP binary provide every PHP extension required by Composer?
- Should Composer stay installed for updates or be removed after install?
- Should Bun stay installed for updates or be removed after asset generation?
