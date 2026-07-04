# Phase 4 - Application Installation

This phase installs the WatchState source tree and validates the application console before creating native systemd services.

## Upstream Source

Repository:

```text
https://github.com/arabcoders/watchstate.git
```

Default branch:

```text
master
```

## Goals

- Clone the upstream WatchState source into `/opt/app`.
- Keep the native layout close to the upstream Docker image.
- Install PHP dependencies as the `watchstate` service user where practical.
- Install/build frontend assets with Bun.
- Validate the application console before creating services.
- Avoid real application secrets in this repository.

## Initial Source Layout

Target paths:

```text
/opt/app       WatchState source tree
/config        Persistent data path
/opt/bin       Helper commands and symlinks
/opt/config    Runtime config outside source tree
```

## Safety Rules

Do not commit or document real values for:

- API tokens
- app-generated API keys
- real `.env` files
- database files
- private URLs
- logs with sensitive values

Use placeholders when documentation needs examples.

## Planned Steps

1. Clone upstream source into `/opt/app`.
2. Record upstream commit hash.
3. Confirm source files expected from upstream analysis exist.
4. Create helper symlink `/opt/bin/console` to `/opt/app/bin/console`.
5. Run Composer dependency install as `watchstate` if possible.
6. Run frontend dependency install/build with Bun.
7. Run application console validation.
8. Run upstream initialization commands manually before service creation.

## Deferred Items

Do not create these until console and manual startup validation are complete:

- `watchstate-web.service`
- `watchstate-scheduler.service`
- WatchState-specific Redis override/config
- Reverse proxy configuration

## Open Questions

- Whether Debian PHP-FPM plus a web server is sufficient, or FrankenPHP should still be used to match upstream web serving.
- Whether frontend build output exactly matches the upstream Docker placement under `/opt/app/public/exported/`.
- Whether Redis should remain the default Debian service or move to a WatchState-specific Redis unit using upstream config.
