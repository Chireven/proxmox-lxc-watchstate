# Upstream WatchState Analysis

This file tracks findings from the official WatchState repository.

## Files Reviewed

- Dockerfile
- container/files/init-container.sh
- container/files/runner.sh
- container/files/redis.conf
- README.md
- FAQ.md

## Initial Findings

- The official image is based on Debian 13.
- The web runtime is FrankenPHP.
- The web UI listens on port 8080.
- Persistent data is stored under `/config`.
- Redis is started by default for cache support.
- FFmpeg and FFprobe are included in the official image.
- Frontend assets are built with Bun during the image build.
- Composer is used to install PHP dependencies.

## Important Scheduler Finding

WatchState does not require manual system scheduler edits for normal task configuration.

The container starts a helper loop that runs the WatchState scheduler command every 60 seconds. The application UI controls which tasks are enabled and how they are scheduled.

For the native LXC install, we should reproduce this as a managed service rather than manually editing host or container scheduler files.

## Next Research Questions

- Which PHP extensions are included in the upstream FrankenPHP build?
- Should native LXC use standalone FrankenPHP or a traditional web server plus PHP-FPM?
- Should Redis run as a Debian service or as an app-local service?
- Can Debian FFmpeg replace the Jellyfin FFmpeg binary used by the container?
