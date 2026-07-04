# Update Assumptions

This document captures assumptions for updating a native WatchState LXC installation.

## Why Updates Need Care

WatchState updates may include database migrations, schema changes, configuration changes, and frontend changes.

The upstream container handles this by rebuilding the image and then running initialization logic during container startup.

A native installation needs to reproduce that behavior deliberately.

## First-Pass Native Update Model

A safe native update should follow this order:

1. Stop WatchState services.
2. Back up persistent data under `/config`.
3. Back up the current application source or record the current git revision.
4. Pull or checkout the target WatchState release.
5. Install PHP dependencies with Composer.
6. Rebuild frontend assets with Bun.
7. Run the same initialization commands used at startup.
8. Restart services.
9. Verify the health endpoint and web UI.
10. Keep the previous backup until the new version is confirmed healthy.

## Items That Likely Need to Run on Update

- Composer dependency installation
- Frontend asset generation
- Route cache refresh
- Event listener cache refresh
- Legacy database import check
- Database migrations
- Database maintenance
- Database index check

## Backup Scope

Minimum backup target:

```text
/config
```

Recommended additional state:

```text
/opt/app current git revision
/opt/config runtime config files
systemd unit files
```

## Upgrade Policy

Initial policy: do not auto-update blindly.

Updates should be manual until the native deployment is proven reliable. The first update script should be conservative, verbose, and easy to interrupt before making changes.

## Open Questions

- Should the updater track specific WatchState releases or follow the default branch?
- Should the updater keep Composer and Bun installed permanently?
- Should migrations be run by a dedicated command before the web service starts?
- Should the backup be a tar archive, ZFS snapshot, Proxmox backup, or a combination?
