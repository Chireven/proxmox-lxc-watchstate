# Dependency Plan

This file tracks native LXC dependency decisions for WatchState.

## Confirmed PHP Requirements

WatchState `composer.json` requires PHP `^8.4` and these extensions:

- pdo
- pdo_sqlite
- mbstring
- ctype
- curl
- sodium
- simplexml
- fileinfo
- redis
- posix
- openssl
- zip

## Debian 13 PHP Availability

Debian 13 / Trixie provides PHP 8.4 packages directly from the default repository.

Validated package candidates:

| Package | Candidate |
| --- | --- |
| php | 2:8.4+96 |
| php-cli | 2:8.4+96 |
| php-fpm | 2:8.4+96 |
| php-redis | 6.2.0-1 |
| php-sqlite3 | 2:8.4+96 |
| php-mbstring | 2:8.4+96 |
| php-curl | 2:8.4+96 |
| php-xml | 2:8.4+96 |
| php-zip | 2:8.4+96 |

The default Debian repository does not expose a `frankenphp` package.

## Frontend Build Requirements

The frontend is a Nuxt application. The upstream Docker build installs Bun and runs the frontend generate task during image build.

Initial decision: treat Bun as build-time only unless runtime testing proves otherwise.

## Runtime Package Direction

Current native direction:

- Use Debian 13 as the LXC base.
- Use Debian PHP 8.4 packages to satisfy Composer platform requirements.
- Keep Composer available during install and update.
- Use local Redis first.
- Use SQLite for database storage.
- Use Debian FFmpeg first, then switch only if testing shows the Jellyfin FFmpeg build is required.
- Use FrankenPHP later if practical for web serving, but do not block PHP dependency validation on it.

## Open Items

- Decide whether final web serving uses standalone FrankenPHP or Debian PHP-FPM plus a traditional web server.
- Decide whether Redis should run as the normal Debian service or as a WatchState-specific service.
- Validate that Composer accepts the Debian PHP extension set.
