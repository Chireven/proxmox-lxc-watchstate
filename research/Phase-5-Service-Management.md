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

FrankenPHP was installed directly as a binary at:

```text
/opt/bin/frankenphp
```

Validated version:

```text
FrankenPHP v1.12.4
PHP 8.5.8
Caddy v2.11.4
```

The direct binary uses its own embedded PHP runtime. Required WatchState extensions were validated under FrankenPHP's PHP runtime.

Required extension validation result:

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

The WatchState console was validated through FrankenPHP:

```text
cd /opt/app && WS_DATA_PATH=/config /opt/bin/frankenphp php-cli bin/console --help
```

Observed result:

- Console help listed normally.
- The command ran successfully as the `watchstate` user.

FrankenPHP web serving was validated manually with:

```text
cd /opt/app && WS_DATA_PATH=/config /opt/bin/frankenphp php-server --listen 0.0.0.0:8080 --root /opt/app/public
```

Healthcheck validation result:

```text
HTTP/1.1 200 OK
Server: FrankenPHP Caddy
X-Powered-By: PHP/8.5.8
{"status":"ok","message":"System is healthy"}
```

This confirms WatchState runs successfully under FrankenPHP and is ready for systemd service creation.

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

## Proposed Native Services

### watchstate-web.service

Purpose:

- Run the WatchState web application through FrankenPHP.

Expected command model:

```text
/opt/bin/frankenphp php-server --listen 0.0.0.0:8080 --root /opt/app/public
```

Expected service user:

```text
watchstate
```

Expected environment:

```text
WS_DATA_PATH=/config
WS_TZ=UTC
PATH=/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

### watchstate-scheduler.service

Purpose:

- Reproduce the upstream scheduler loop from `container/files/runner.sh`.

Expected command behavior:

```text
while true; do
  /opt/bin/console system:scheduler --pid-file /tmp/ws-job-runner.pid
  sleep 60
done
```

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

## Deferred Items

- Reverse proxy configuration.
- TLS certificates.
- External Redis.
- Host bind mounts.
