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

## First Validation Result

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

## PHP Runtime Install Group

Installed Debian PHP 8.4 runtime packages:

- php-cli
- php-fpm
- php-sqlite3
- php-mbstring
- php-curl
- php-xml
- php-zip
- php-redis

## PHP Runtime Validation Result

Validated successfully.

Observed PHP version:

```text
PHP 8.4.23 CLI
Zend OPcache 8.4.23
```

Required WatchState extensions confirmed present:

- PDO
- pdo_sqlite
- mbstring
- ctype
- curl
- sodium
- SimpleXML
- fileinfo
- redis
- posix
- openssl
- zip

Additional useful modules observed:

- dom
- xml
- xmlreader
- xmlwriter
- xsl
- sqlite3
- sockets
- pcntl
- opcache

PHP configuration path:

```text
/etc/php/8.4/cli/php.ini
/etc/php/8.4/cli/conf.d
```

PHP-FPM service status:

- `php8.4-fpm.service` enabled
- `php8.4-fpm.service` active and running
- Ready to handle connections

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

Install and validate Composer, then use Composer platform checks later to confirm the WatchState dependency requirements are satisfied by Debian PHP.
