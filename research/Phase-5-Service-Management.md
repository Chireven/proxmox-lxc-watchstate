# Phase 5 - Native Service Management

This phase turns the manually validated native WatchState install into a production-oriented systemd-managed deployment.

## Service Runtime Decision

Use FrankenPHP for the production web service.

Do not use PHP's built-in web server for the service deployment. It was used only for manual validation.

Rationale:

- Upstream WatchState uses FrankenPHP in the Docker image.
- Upstream starts the application with `frankenphp php-server --listen 0.0.0.0:8080 --root /opt/app/public`.
- Matching upstream reduces drift between Docker and native LXC behavior.
- The native project goal is a production-style deployment, not a proof-of-function deployment.

## FrankenPHP Binary Validation

FrankenPHP was installed directly as a binary at `/opt/bin/frankenphp`.

Validated version:

```text
FrankenPHP v1.12.4
PHP 8.5.8
Caddy v2.11.4
```

Required WatchState extensions were validated under FrankenPHP's PHP runtime:

```text
PDO: yes
pdo_sqlite: yes
mbstring: yes
ctype: yes
curl: yes
sodium: yes
SimpleXML: yes
fileinfo: yes
redis: yes
posix: yes
openssl: yes
zip: yes
```

The WatchState console was validated through FrankenPHP and console help listed normally.

FrankenPHP web serving was validated manually. Healthcheck returned healthy through `Server: FrankenPHP Caddy` with `X-Powered-By: PHP/8.5.8`.

## Snapshot Checkpoint

A Proxmox snapshot was taken after FrankenPHP validation and before creating native systemd service units.

Snapshot name:

```text
watchstate-phase-5-frankenphp-validated
```

Checkpoint scope:

- WatchState source installed.
- Composer dependencies installed.
- Frontend dependencies installed.
- Frontend generated and copied to `/opt/app/public/exported`.
- Application initialized under `/config`.
- SQLite database created and migrated.
- Redis validated.
- FrankenPHP binary installed.
- FrankenPHP PHP runtime validated.
- FrankenPHP healthcheck validated.
- No native WatchState systemd units created yet.

## watchstate-web.service Validation

The production web service unit was created at `/etc/systemd/system/watchstate-web.service` and is tracked in the repository at `systemd/watchstate-web.service`.

Service status after enable/start:

```text
Loaded: loaded and enabled
Active: active running
Main process: frankenphp
```

Healthcheck validation through the systemd service returned healthy through FrankenPHP Caddy with PHP 8.5.8.

Observed service log notes:

- `admin endpoint disabled` is expected for this command mode.
- HTTP/2 and HTTP/3 skipped warnings are expected while serving plain HTTP on port 8080.

## watchstate-scheduler.service Validation

The scheduler service unit was created at `/etc/systemd/system/watchstate-scheduler.service` and is tracked in the repository at `systemd/watchstate-scheduler.service`.

The unit reproduces the upstream scheduler loop using FrankenPHP's PHP CLI runtime.

Service status after enable/start:

```text
Loaded: loaded and enabled
Active: active running
Main process: bash
Child process: frankenphp php-cli running WatchState scheduler
```

Runtime PID file validation:

```text
/tmp/ws-job-runner.pid exists and is owned by watchstate:watchstate
```

This confirms the native scheduler service starts and runs under systemd.

## Proposed Native Services

### watchstate-web.service

Status: created, enabled, running, and validated.

Purpose:

- Run the WatchState web application through FrankenPHP.

### watchstate-scheduler.service

Status: created, enabled, running, and validated.

Purpose:

- Reproduce the upstream scheduler loop from `container/files/runner.sh`.

### redis-server.service

Initial decision:

- Keep Debian Redis service for now because it is already active, local, and responds to `redis-cli ping`.
- Revisit whether to switch to WatchState-specific Redis config after web service validation.

## Required Before Creating Services

Complete.

- FrankenPHP binary installed.
- FrankenPHP PHP runtime validated.
- WatchState required extensions validated under FrankenPHP.
- WatchState console validated under FrankenPHP.
- Healthcheck validated through FrankenPHP.
- Snapshot checkpoint completed before systemd service creation.
- `watchstate-web.service` created and validated.
- `watchstate-scheduler.service` created and validated.

## Deferred Items

- Reverse proxy configuration.
- TLS certificates.
- External Redis.
- Host bind mounts.
