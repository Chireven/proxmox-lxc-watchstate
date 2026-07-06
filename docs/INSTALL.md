# Native WatchState install guide for Proxmox LXC

This guide installs WatchState natively inside an existing Debian-based Proxmox LXC container without Docker.

The helper scripts are designed to run from the Proxmox host. The host does not need Git or development tools. Build and runtime dependencies are installed inside the target LXC only.

## Validated layout

Inside the target container:

```text
/opt/app              WatchState source tree
/config               Persistent WatchState config and data
/opt/bin/frankenphp   FrankenPHP static binary
/usr/local/bin/bun    Bun frontend tool
```

Native services:

```text
redis-server.service
watchstate-web.service
watchstate-scheduler.service
```

Healthcheck:

```text
http://127.0.0.1:8080/v1/api/system/healthcheck
```

## Proxmox host script location

The validated workflow copies only the helper scripts to the Proxmox host:

```text
/scripts/watchstate
```

Create the directory on the Proxmox host:

```bash
mkdir -p /scripts/watchstate
cd /scripts/watchstate
```

Download the current scripts:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/Chireven/proxmox-lxc-watchstate/main/scripts/install-watchstate.sh \
  -o install-watchstate.sh

curl -fsSL \
  https://raw.githubusercontent.com/Chireven/proxmox-lxc-watchstate/main/scripts/verify-watchstate.sh \
  -o verify-watchstate.sh

curl -fsSL \
  https://raw.githubusercontent.com/Chireven/proxmox-lxc-watchstate/main/scripts/update-watchstate.sh \
  -o update-watchstate.sh

curl -fsSL \
  https://raw.githubusercontent.com/Chireven/proxmox-lxc-watchstate/main/scripts/backup-watchstate.sh \
  -o backup-watchstate.sh

chmod 0755 *.sh
```

## Container requirements

Start with a clean Debian LXC container.

Recommended minimum for install/build:

```text
Memory: 2 GB minimum; 4 GB preferred during frontend generation
Swap:   1-2 GB recommended
Disk:   8 GB minimum; more if keeping app source and package caches
OS:     Debian-based LXC with systemd
```

The frontend generation step can be memory-intensive. If the build exits with code `137` or mentions `SIGKILL`, increase CT memory and swap.

Confirm the CT is running:

```bash
pct status 104
```

If needed:

```bash
pct start 104
```

## Install

Run on the Proxmox host:

```bash
cd /scripts/watchstate
./install-watchstate.sh --ctid 104 2>&1 | tee "install-104.$(date +%Y%m%d-%H%M%S).log"
```

The installer performs these actions inside the CT:

- installs Debian package prerequisites;
- creates the `watchstate` user and group;
- creates `/opt/app`, `/config`, and `/opt/bin`;
- installs Bun to `/usr/local/bin/bun`;
- downloads the latest FrankenPHP static binary for the CT architecture;
- clones or copies WatchState source to `/opt/app`;
- normalizes copied source line endings and restores `/opt/app/bin/console` execute permissions;
- installs Composer dependencies;
- installs frontend dependencies and generates frontend output;
- initializes WatchState runtime/database state;
- installs native systemd units;
- starts Redis, web, and scheduler services;
- runs post-install verification when `verify-watchstate.sh` is available.

The script can run without the full repository layout. If `systemd/` templates are not available next to the script, it writes embedded service units into the CT.

### Local or beta source testing

To test a non-production WatchState source tree or archive, pass `--source`:

```bash
./install-watchstate.sh --ctid 104 --source /root/watchstate-source.zip
./update-watchstate.sh --ctid 104 --source /root/watchstate-source
```

Supported source formats are directories, `.zip`, `.tgz`, and `.tar.gz` archives. Local directory archives exclude `.git`, `vendor`, and `node_modules`; dependencies are rebuilt inside the target CT. After source extraction, the scripts normalize CRLF line endings in PHP, shell, and console entrypoint files and make `/opt/app/bin/console` executable. This prevents Windows-created ZIP files from producing `env: 'php\r': No such file or directory` or permission-denied errors when WatchState runs console commands.

## Verify

Run on the Proxmox host:

```bash
cd /scripts/watchstate
./verify-watchstate.sh --ctid 104
```

The verifier checks:

- CT availability;
- service user/group;
- expected paths and ownership;
- Redis, web, and scheduler service state;
- FrankenPHP, Redis, and healthcheck runtime state;
- Git or local-source state;
- frontend output;
- required tools;
- database presence;
- migration dry-run status.

Warnings should be reviewed. Failures indicate the install or runtime state needs correction.

## Update

Run on the Proxmox host:

```bash
cd /scripts/watchstate
./update-watchstate.sh --ctid 104
```

By default, the update script:

- runs a pre-update backup;
- creates a Proxmox snapshot;
- stops WatchState services;
- fast-forwards or replaces the WatchState source tree;
- normalizes copied source line endings and restores `/opt/app/bin/console` execute permissions;
- updates Composer dependencies;
- updates frontend dependencies and regenerates frontend output;
- runs database migration/index/cache tasks;
- restarts services;
- validates the healthcheck;
- runs post-update verification.

Useful options:

```bash
./update-watchstate.sh --ctid 104 --skip-snapshot
./update-watchstate.sh --ctid 104 --skip-backup
./update-watchstate.sh --ctid 104 --skip-verify
./update-watchstate.sh --ctid 104 --backup-root /mnt/backups/watchstate
```

## Backup

Run on the Proxmox host:

```bash
cd /scripts/watchstate
./backup-watchstate.sh --ctid 104
```

Default backup root:

```text
/root/watchstate-backups
```

Useful options:

```bash
./backup-watchstate.sh --ctid 104 --list
./backup-watchstate.sh --ctid 104 --backup-root /mnt/backups/watchstate
./backup-watchstate.sh --ctid 104 --keep 30
./backup-watchstate.sh --ctid 104 --prune-only --prune-dry-run
```

## Common notes

### Locale warnings

Minimal Debian containers may print warnings like:

```text
perl: warning: Setting locale failed.
locale: Cannot set LC_CTYPE to default locale: No such file or directory
```

These warnings are usually harmless if package installation continues and verification passes.

### Bun path

Bun is installed at:

```text
/usr/local/bin/bun
```

Some non-login `pct exec ... sh -c` environments do not include `/usr/local/bin` in `PATH`. The validated scripts use the explicit path or export a PATH that includes `/usr/local/bin`.

### FrankenPHP binary

The installer downloads the latest static FrankenPHP binary using this pattern:

```text
https://github.com/php/frankenphp/releases/latest/download/frankenphp-linux-$(uname -m)
```

To pin a specific validated binary, pass:

```bash
./install-watchstate.sh --ctid 104 --frankenphp-url '<direct-frankenphp-binary-url>'
```

## Production cutover checklist

Before using a CT as production:

1. Run `verify-watchstate.sh` and review all warnings.
2. Confirm the web UI loads.
3. Complete first login and application configuration.
4. Enable scheduled tasks from the WatchState UI.
5. Run a backup.
6. Create a Proxmox snapshot.
7. Document the CT ID, hostname, IP, and backup path.
