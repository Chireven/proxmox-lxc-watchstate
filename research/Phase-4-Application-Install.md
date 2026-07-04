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

Native install note:

- Upstream Docker copies generated frontend output into `/opt/app/public/exported`.
- Native install must explicitly copy `/opt/app/frontend/exported` to `/opt/app/public/exported` after `bun run generate`.

## Planned Steps

1. Clone upstream source into `/opt/app`. Done.
2. Record upstream commit hash. Done.
3. Confirm source files expected from upstream analysis exist. Done.
4. Create helper symlink `/opt/bin/console` to `/opt/app/bin/console`. Done.
5. Run Composer dependency install as `watchstate` if possible. Done.
6. Run frontend dependency install/build with Bun. Build done; copy generated output into app public path next.
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
- Whether Redis should remain the default Debian service or move to a WatchState-specific Redis unit using upstream config.
