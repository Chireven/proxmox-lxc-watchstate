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

## Frontend Build Requirements

The frontend is a Nuxt application. The upstream Docker build installs Bun and runs the frontend generate task during image build.

Initial decision: treat Bun as build-time only unless runtime testing proves otherwise.

## Runtime Package Direction

Initial native direction:

- Use Debian 13 as the LXC base.
- Use PHP 8.4-compatible runtime via FrankenPHP if practical.
- Keep Composer available during install and update.
- Use local Redis first.
- Use SQLite for database storage.
- Use Debian FFmpeg first, then switch only if testing shows the Jellyfin FFmpeg build is required.

## Open Items

- Identify the exact PHP extensions bundled in upstream FrankenPHP.
- Decide whether to use standalone FrankenPHP or Debian PHP packages plus a traditional web server.
- Decide whether Redis should run as the normal Debian service or as a WatchState-specific service.
