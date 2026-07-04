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

- Install or obtain a suitable FrankenPHP binary.
- Validate that the FrankenPHP binary can run PHP CLI commands needed by WatchState.
- Generate or adopt a production PHP configuration if required.
- Verify healthcheck through FrankenPHP, not PHP's built-in server.

## Deferred Items

- Reverse proxy configuration.
- TLS certificates.
- External Redis.
- Host bind mounts.
