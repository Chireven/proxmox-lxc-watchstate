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

## Source Checkout Result

WatchState source was cloned into `/opt/app`.

Validated checkout:

```text
branch: master
commit: 9a4c8225e3d9502ae759b74fe301ae5d52df7c54
```

Working tree validation:

- `git status --short` returned no output when run as `watchstate`.
- This indicates a clean checkout.

Important source files validated:

- `/opt/app/composer.json`
- `/opt/app/frontend/package.json`
- `/opt/app/bin/console`

Operational note:

- The repository is owned by `watchstate:watchstate`.
- Git checks should normally be run as the `watchstate` user using `runuser -u watchstate -- git -C /opt/app ...`.
- Running Git against `/opt/app` as root triggers Git's dubious ownership protection, which is expected and should not be bypassed unless needed for a specific administrative reason.

## Console Symlink Result

Created the upstream-aligned helper symlink:

```text
/opt/bin/console -> /opt/app/bin/console
```

Validation:

```text
lrwxrwxrwx 1 watchstate watchstate ... /opt/bin/console -> /opt/app/bin/console
readlink -f /opt/bin/console = /opt/app/bin/console
console symlink executable
```

## Composer Dependency Result

Composer platform validation succeeded before installing dependencies from the lock file.

Initial check:

- No `vendor` directory was present yet.
- Composer checked platform requirements from `composer.lock`.
- All required PHP platform requirements succeeded.

Composer install command model:

```text
runuser -u watchstate -- composer install --working-dir=/opt/app --no-dev --prefer-dist --no-interaction --optimize-autoloader
```

Install result:

- 39 package installs
- 0 updates
- 0 removals
- Optimized autoload files generated
- `/opt/app/vendor` created and owned by `watchstate:watchstate`

Post-install platform validation succeeded against the installed vendor directory.

Validated platform requirements include:

- ext-ctype
- ext-curl
- ext-fileinfo
- ext-json
- ext-mbstring
- ext-openssl
- ext-pdo
- ext-pdo_sqlite
- ext-posix
- ext-redis
- ext-simplexml
- ext-sodium
- ext-zip
- php 8.4.23

## Planned Steps

1. Clone upstream source into `/opt/app`. Done.
2. Record upstream commit hash. Done.
3. Confirm source files expected from upstream analysis exist. Done.
4. Create helper symlink `/opt/bin/console` to `/opt/app/bin/console`. Done.
5. Run Composer dependency install as `watchstate` if possible. Done.
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
