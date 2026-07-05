# Media integration guide

This guide documents the recommended media integration model for a native WatchState deployment inside a Proxmox LXC container.

WatchState normally syncs watched/play state through media-backend APIs. For Plex, Jellyfin, and Emby integrations, the WatchState CT does not normally need direct filesystem access to the media files.

The validated application layout remains:

```text
/opt/app    WatchState source tree
/config    Persistent WatchState config and data
```

## Key point

Do not add Proxmox media bind mounts to the WatchState CT by default.

For normal WatchState usage, validate API connectivity and watched-state behavior instead of validating media filesystem access.

## What WatchState needs

Typical requirements:

- network access from the WatchState CT to each Plex/Jellyfin/Emby backend;
- valid backend URLs;
- valid backend tokens/API credentials;
- configured WatchState identities/users;
- enabled import/export jobs or webhooks, depending on the desired sync model;
- persistent write access to `/config` for WatchState state.

Typical non-requirements:

- direct access to `/media`;
- Proxmox bind mounts for movie or TV libraries;
- ownership of media files by the `watchstate` user;
- shared media group membership inside the WatchState CT.

## When bind mounts might be useful

Bind mounts are optional and should only be considered for a specific tested reason, such as:

- local troubleshooting where seeing the media tree from inside the CT is useful;
- a future WatchState feature or custom workflow that explicitly requires local filesystem access;
- an administrative preference to compare backend-reported paths against local paths manually.

Even then, prefer read-only mounts. WatchState should not own the media library.

## Path matching clarification

WatchState path matching does not require the WatchState CT to mount the media files.

Path matching uses media paths reported by the backends and derives a `guid_path` value from those paths. This can help when backends share the same files but have unreliable, missing, or inconsistent external IDs.

The important part is backend path consistency, especially the trailing path suffixes used by WatchState. The local CT does not need to read the files for this matching mode.

## Recommended validation for two Plex servers

For a two-Plex-server setup, Phase 7 should validate watched-state sync, not media bind mounts.

Recommended test flow:

1. Confirm both Plex servers are reachable from the WatchState CT.
2. Confirm both Plex backends are configured in WatchState.
3. Choose one movie or episode that exists on both Plex servers.
4. Mark the item watched on Plex server A.
5. Run or wait for the WatchState import job for Plex server A.
6. Confirm WatchState shows or stores the watched state for that item/user.
7. Run or wait for the WatchState export/sync job to Plex server B.
8. Confirm Plex server B marks the same item watched for the intended user.
9. Repeat in the opposite direction if bidirectional sync is intended.
10. Repeat with one episode as well as one movie if both library types are used.

## Network validation

Run on Proxmox host:

```bash
pct exec 103 -- getent hosts <plex-server-a-hostname>
pct exec 103 -- getent hosts <plex-server-b-hostname>
pct exec 103 -- curl -fsS http://<plex-server-a-hostname>:32400/identity
pct exec 103 -- curl -fsS http://<plex-server-b-hostname>:32400/identity
```

Use HTTPS and the correct port if your Plex servers require it.

## WatchState health validation

Run on Proxmox host:

```bash
cd /scripts/watchstate
./verify-watchstate.sh --ctid 103
```

The WatchState healthcheck should pass before troubleshooting backend sync behavior.

## WatchState UI validation

In the WatchState UI:

1. Confirm both Plex backends are configured.
2. Confirm each backend is assigned to the correct WatchState identity/user.
3. Confirm the desired sync direction: one-way or two-way.
4. Confirm import/export jobs are enabled as intended.
5. Run a manual import for one backend.
6. Review logs for unmatched or mismatched items.
7. Run a manual export/sync to the other backend.
8. Confirm watched state changed in Plex.

## Optional path-matching validation

Only enable path matching if normal GUID matching is unreliable.

Suggested validation:

1. Pick an item that fails to match reliably by normal identifiers.
2. Confirm both Plex servers report stable media paths for that same item.
3. Enable WatchState path matching from the WatchState environment configuration.
4. Run a full import/backfill as described by the upstream path-matching guide.
5. Review WatchState logs for match improvements.
6. Confirm watched-state sync works for the test item.

## If bind mounts are intentionally added

If you still choose to add media bind mounts for troubleshooting, keep them read-only.

Run on Proxmox host:

```bash
pct set 103 -mp0 /media/movies/vol.001,mp=/media/movies/vol.001,ro=1
pct reboot 103
```

Validate the mount only as an optional filesystem check:

Run on Proxmox host:

```bash
pct exec 103 -- findmnt /media/movies/vol.001
pct exec 103 -- ls -ld /media /media/movies /media/movies/vol.001
```

This is not required for normal WatchState watched-state sync.

## Snapshot after validation

After confirming backend connectivity and watched-state sync behavior:

Run on Proxmox host:

```bash
pct snapshot 103 watchstate-phase-7-api-sync-validated
```

## Troubleshooting

### Plex backend is unreachable

Run on Proxmox host:

```bash
pct exec 103 -- getent hosts <plex-server-hostname>
pct exec 103 -- curl -v http://<plex-server-hostname>:32400/identity
```

Check DNS, routing, firewall rules, Plex remote access settings, and whether the backend URL configured in WatchState is reachable from inside the CT.

### Items do not match between Plex servers

Check:

- both libraries contain the same movie or episode;
- metadata agents produced compatible external IDs;
- the item is assigned to the same intended user/identity;
- WatchState logs do not show unmatched or mismatched records;
- path matching is only enabled if needed and after understanding its suffix-based behavior.

### Watched state imports but does not export

Check:

- sync direction is correct;
- export/sync jobs are enabled;
- the target Plex backend has a matching item;
- the target user exists and is mapped correctly;
- WatchState logs show the export attempt.

## Public repository safety

Do not commit:

- Plex tokens;
- backend API keys;
- private backend URLs;
- private hostnames or IP addresses;
- WatchState database files;
- backup archives;
- logs containing private library contents or account data.

Use placeholders such as `<plex-server-a-hostname>`, `<plex-server-b-hostname>`, `<CTID>`, and `<token>` in documentation.
