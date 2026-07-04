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

## Source Checkout Result

WatchState source was cloned into `/opt/app`.

Validated checkout:

```text
branch: master
commit: 9a4c8225e3d9502ae759b74fe301ae5d52df7c54
```

Important source files validated:

- `/opt/app/composer.json`
- `/opt/app/frontend/package.json`
- `/opt/app/bin/console`

## Console Symlink Result

Created and validated:

```text
/opt/bin/console -> /opt/app/bin/console
```

## Composer Dependency Result

Composer install completed successfully as the `watchstate` user.

Result:

- 39 package installs
- 0 updates
- 0 removals
- `/opt/app/vendor` owned by `watchstate:watchstate`
- Post-install platform validation succeeded
- PHP validated at 8.4.23

## Frontend Build Result

Frontend ownership validation succeeded.

`bun install --frozen-lockfile --production` completed successfully as the `watchstate` user.

Result:

- 977 packages installed
- `node_modules` created under `/opt/app/frontend`
- `node_modules` owned by `watchstate:watchstate`
- Nuxt prepare completed successfully

`bun run generate` completed successfully as the `watchstate` user.

Result:

- Nuxt production build succeeded
- Nitro static preset used
- 30 routes prerendered
- Fonts downloaded and cached
- Static frontend generated under `/opt/app/frontend/exported`

## Frontend Public Asset Copy Result

Copied the generated frontend from:

```text
/opt/app/frontend/exported
```

To the upstream-aligned application public path:

```text
/opt/app/public/exported
```

Validation result:

- `/opt/app/public/exported` exists.
- `/opt/app/public/exported` is owned by `watchstate:watchstate`.
- `index.html` exists.
- `200.html` exists.
- Static route files and image/font assets are present.

## Console Validation Result

Application console validation succeeded as the `watchstate` user with `WS_DATA_PATH=/config`.

Validation commands:

```text
cd /opt/app && WS_DATA_PATH=/config php bin/console --help
cd /opt/app && WS_DATA_PATH=/config php bin/console -q
```

Observed result:

- `bin/console --help` listed console usage normally.
- `bin/console -q` returned to the prompt with no errors.
- This confirms the PHP dependency install, console entry point, and `/config` data path are usable at a basic level.

## Manual Initialization Result

Before running the upstream-style initialization sequence, `/config` already contained application-created paths and the SQLite database:

```text
/config/db/watchstate_v02.db
/config/console
/config/queue
/config/users
```

No files were present under `/config/logs` or `/config/debug` at the time of inspection.

The following upstream-style initialization commands were run as the `watchstate` user with `WS_DATA_PATH=/config`:

```text
WS_CACHE_NULL=1 php bin/console -q
php bin/console system:routes
php bin/console events:cache
php bin/console db:legacy --execute
CONTAINER_INIT=1 php bin/console db:migrate --execute
php bin/console db:maintenance
php bin/console db:index
php bin/console system:apikey -q
```

Observed result:

- Most commands returned to the prompt with no output or errors.
- `db:migrate --execute` reported: `main: Applied 1 migration(s).`
- No secrets or generated API key values were printed to the terminal.

## Planned Steps

1. Clone upstream source into `/opt/app`. Done.
2. Record upstream commit hash. Done.
3. Confirm source files expected from upstream analysis exist. Done.
4. Create helper symlink `/opt/bin/console` to `/opt/app/bin/console`. Done.
5. Run Composer dependency install as `watchstate` if possible. Done.
6. Run frontend dependency install/build with Bun. Done.
7. Run application console validation. Done.
8. Run upstream initialization commands manually before service creation. Done.

## Deferred Items

Do not create these until manual web validation is complete:

- `watchstate-web.service`
- `watchstate-scheduler.service`
- WatchState-specific Redis override/config
- Reverse proxy configuration

## Open Questions

- Whether Debian PHP-FPM plus a web server is sufficient, or FrankenPHP should still be used to match upstream web serving.
- Whether Redis should remain the default Debian service or move to a WatchState-specific Redis unit using upstream config.
