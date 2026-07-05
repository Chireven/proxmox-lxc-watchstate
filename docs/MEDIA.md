# Media integration guide

This guide documents the recommended media integration model for a native WatchState deployment inside a Proxmox LXC container.

The validated WatchState application install should already be healthy before adding media mounts. Keep the application runtime under `/opt/app` and persistent WatchState data under `/config`. Media libraries should be mounted separately.

## Goals

- Keep Docker out of the runtime path.
- Keep the Proxmox host lightweight.
- Keep helper scripts under `/scripts/watchstate`.
- Add media access through Proxmox bind mounts.
- Avoid giving WatchState ownership of media libraries.
- Prefer read-only media mounts unless write access is explicitly required.
- Keep Plex, Jellyfin, and WatchState path mappings consistent.

## Recommended model

WatchState should be treated as a media metadata consumer, not the owner of the media files.

Recommended defaults:

```text
WatchState app/config: /opt/app and /config
Media inside CT:      /media
Mount mode:           read-only where possible
Service user:         watchstate
Shared media group:   media
```

Use read/write mounts only when a tested WatchState workflow requires file writes to the media tree. For normal library visibility and matching, read-only access is safer.

## Example directory layout

Example host paths:

```text
/media/movies/vol.001
/media/tv/vol.001
/media/anime/vol.001
```

Matching CT paths:

```text
/media/movies/vol.001
/media/tv/vol.001
/media/anime/vol.001
```

Keeping the same path inside Plex, Jellyfin, and WatchState reduces path translation mistakes.

## Before changing mounts

Run on Proxmox host:

```bash
cd /scripts/watchstate
./backup-watchstate.sh --ctid 103
pct snapshot 103 watchstate-pre-media-integration
./verify-watchstate.sh --ctid 103
```

Review any verification failures before adding media mounts.

## Inspect the current CT configuration

Run on Proxmox host:

```bash
pct config 103
pct status 103
```

Choose unused mount point numbers such as `mp0`, `mp1`, and `mp2`.

## Add read-only bind mounts

Run on Proxmox host:

```bash
pct set 103 -mp0 /media/movies/vol.001,mp=/media/movies/vol.001,ro=1
pct set 103 -mp1 /media/tv/vol.001,mp=/media/tv/vol.001,ro=1
pct set 103 -mp2 /media/anime/vol.001,mp=/media/anime/vol.001,ro=1
pct reboot 103
```

Adjust the host paths and CT paths for the actual library layout.

Do not use `pct restart`. Use `pct reboot` for this project.

## Validate the mounts

Run on Proxmox host:

```bash
pct exec 103 -- findmnt /media/movies/vol.001
pct exec 103 -- findmnt /media/tv/vol.001
pct exec 103 -- findmnt /media/anime/vol.001

pct exec 103 -- ls -ld /media /media/movies /media/movies/vol.001
pct exec 103 -- ls -ld /media /media/tv /media/tv/vol.001
pct exec 103 -- ls -ld /media /media/anime /media/anime/vol.001
```

Confirm the mount sources and paths are correct before changing permissions.

## Permissions model

Use a shared `media` group so WatchState can read media without owning it.

The exact group ID should match the wider Proxmox media environment. If other media containers already use a shared media GID, reuse that value.

Example placeholder:

```text
media group: <MEDIA_GID>
```

If using `9002` in the environment, substitute `9002` for `<MEDIA_GID>` in the examples below.

### Confirm host group

Run on Proxmox host:

```bash
getent group media
```

If the group does not exist and `<MEDIA_GID>` is the chosen shared media GID:

Run on Proxmox host:

```bash
groupadd -g <MEDIA_GID> media
```

### Confirm CT group and service user membership

Run on Proxmox host:

```bash
pct exec 103 -- getent group media
pct exec 103 -- id watchstate
```

If the group does not exist inside the CT:

Run on Proxmox host:

```bash
pct exec 103 -- groupadd -g <MEDIA_GID> media
```

Add the WatchState service user to the shared media group:

Run on Proxmox host:

```bash
pct exec 103 -- usermod -aG media watchstate
pct reboot 103
```

Then verify membership:

Run on Proxmox host:

```bash
pct exec 103 -- id watchstate
```

The output should include the `media` group.

## Validate read access as WatchState

Run on Proxmox host:

```bash
pct exec 103 -- su -s /bin/bash watchstate -c 'find /media -maxdepth 3 -type d | head -50'
pct exec 103 -- su -s /bin/bash watchstate -c 'find /media -type f | head -20'
```

If read access fails, fix group ownership or permissions on the host media tree before changing WatchState configuration.

Do not recursively change ownership of a large media library to `watchstate`. WatchState should not own the media files.

## Optional read/write validation

Only run this if the mount is intentionally read/write.

Run on Proxmox host:

```bash
pct exec 103 -- su -s /bin/bash watchstate -c 'touch /media/.watchstate-write-test && rm /media/.watchstate-write-test'
```

For per-library testing, target the specific mounted path:

Run on Proxmox host:

```bash
pct exec 103 -- su -s /bin/bash watchstate -c 'touch /media/movies/vol.001/.watchstate-write-test && rm /media/movies/vol.001/.watchstate-write-test'
```

A read-only mount should fail this test. That is expected.

## Plex and Jellyfin integration

For Plex and Jellyfin backends, keep library paths consistent across systems where possible.

Recommended pattern:

```text
Plex library path:       /media/movies/vol.001
Jellyfin library path:   /media/movies/vol.001
WatchState media path:   /media/movies/vol.001
```

When identical paths are not possible, document the translation clearly:

```text
Plex path:       /data/movies
Jellyfin path:   /media/movies/vol.001
WatchState path: /media/movies/vol.001
Host path:       /media/movies/vol.001
```

Avoid mixing multiple path styles unless there is a specific reason.

## WatchState UI validation

After bind mounts and permissions are validated:

1. Open the WatchState web UI.
2. Confirm Plex/Jellyfin backend connectivity.
3. Confirm media/library paths match the CT paths.
4. Run a small import or scan job.
5. Review unmatched items before changing path mappings.
6. Run the normal verification script.

Run on Proxmox host:

```bash
cd /scripts/watchstate
./verify-watchstate.sh --ctid 103
```

## Snapshot after validation

After confirming the mounts, permissions, and library scan behavior:

Run on Proxmox host:

```bash
pct snapshot 103 watchstate-phase-7-media-integrated
```

## Troubleshooting

### Mount does not appear inside CT

Run on Proxmox host:

```bash
pct config 103 | grep '^mp'
pct reboot 103
pct exec 103 -- findmnt /media
```

Confirm the host path exists and the mount point number is not duplicated.

### WatchState cannot read media

Run on Proxmox host:

```bash
pct exec 103 -- id watchstate
pct exec 103 -- ls -ld /media /media/movies /media/movies/vol.001
pct exec 103 -- su -s /bin/bash watchstate -c 'find /media -maxdepth 3 -type d | head -50'
```

Common causes:

- `watchstate` is not in the shared `media` group.
- Directory execute permission is missing on a parent directory.
- The host media tree uses a different group ID than the CT expects.
- The CT is unprivileged and the UID/GID mapping does not expose the expected group.

### Read-only mount blocks expected writes

Confirm whether WatchState really needs write access to the media tree. If write access is required, change only the specific mount that needs writes.

Run on Proxmox host:

```bash
pct set 103 -mp0 /media/movies/vol.001,mp=/media/movies/vol.001
pct reboot 103
```

Then run the read/write validation test for that path.

### Plex/Jellyfin paths do not match WatchState paths

Prefer making the CT paths match the existing Plex/Jellyfin library paths. If that is not practical, document each mapping and validate one library at a time.

## Public repository safety

Do not commit:

- private media paths;
- hostnames or internal URLs not meant to be public;
- API tokens;
- WatchState database files;
- backup archives;
- logs containing library contents or private account data.

Use placeholders such as `/media/movies/vol.001`, `<MEDIA_GID>`, and `<CTID>` in documentation.
