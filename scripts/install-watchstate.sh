#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install-watchstate.sh [options]

Install the native WatchState deployment into an existing Debian LXC from the Proxmox host.

This script does not create the LXC. Start with a clean Debian CT, then run this script from the Proxmox host.

Options:
  --ctid <id>                       Proxmox CT ID. Overrides name discovery.
  --name <name>                     Proxmox CT name to discover. Default: watchstate
  --branch <branch>                 WatchState upstream branch. Default: master
  --repo <url>                      WatchState upstream repository. Default: https://github.com/arabcoders/watchstate.git
  --frankenphp-url <url>            Download a specific FrankenPHP binary URL instead of using the install script
  --frankenphp-install-script <url> FrankenPHP installer URL. Default: https://frankenphp.dev/install.sh
  --uid <uid>                       watchstate service UID. Default: 1000
  --gid <gid>                       watchstate service GID. Default: 1000
  --skip-verify                    Do not run verify-watchstate.sh after install
  --force                          Allow install when /opt/app or /config already exists
  -h, --help                       Show this help

Examples:
  ./scripts/install-watchstate.sh --ctid 103
  ./scripts/install-watchstate.sh --name watchstate
  ./scripts/install-watchstate.sh --ctid 103 --frankenphp-url https://example.invalid/frankenphp-linux-x86_64
USAGE
}

CTID=""
CT_NAME="watchstate"
BRANCH="master"
REPO_URL="https://github.com/arabcoders/watchstate.git"
FRANKENPHP_URL=""
FRANKENPHP_INSTALL_SCRIPT="https://frankenphp.dev/install.sh"
WS_UID="1000"
WS_GID="1000"
SKIP_VERIFY="0"
FORCE="0"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ctid)
      CTID="${2:-}"
      shift 2
      ;;
    --name)
      CT_NAME="${2:-}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:-}"
      shift 2
      ;;
    --repo)
      REPO_URL="${2:-}"
      shift 2
      ;;
    --frankenphp-url)
      FRANKENPHP_URL="${2:-}"
      shift 2
      ;;
    --frankenphp-install-script)
      FRANKENPHP_INSTALL_SCRIPT="${2:-}"
      shift 2
      ;;
    --uid)
      WS_UID="${2:-}"
      shift 2
      ;;
    --gid)
      WS_GID="${2:-}"
      shift 2
      ;;
    --skip-verify)
      SKIP_VERIFY="1"
      shift
      ;;
    --force)
      FORCE="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${CT_NAME}" && -z "${CTID}" ]]; then
  echo "ERROR: --name cannot be empty when --ctid is not supplied." >&2
  exit 2
fi

for value_name in WS_UID WS_GID; do
  value="${!value_name}"
  if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: ${value_name} must be a numeric ID." >&2
    exit 2
  fi
done

if [[ -z "${BRANCH}" || -z "${REPO_URL}" || -z "${FRANKENPHP_INSTALL_SCRIPT}" ]]; then
  echo "ERROR: --branch, --repo, and --frankenphp-install-script cannot be empty." >&2
  exit 2
fi

if ! command -v pct >/dev/null 2>&1; then
  echo "ERROR: pct was not found. Run this script on the Proxmox host." >&2
  exit 1
fi

resolve_ctid() {
  if [[ -n "${CTID}" ]]; then
    return
  fi

  local matches match_count
  matches="$(pct list | awk -v name="${CT_NAME}" 'NR > 1 && $NF == name {print $1}')"
  match_count="$(printf '%s\n' "${matches}" | sed '/^$/d' | wc -l | awk '{print $1}')"

  if [[ "${match_count}" == "0" ]]; then
    echo "ERROR: No CT named '${CT_NAME}' was found. Pass --ctid <id> or --name <name>." >&2
    exit 1
  fi

  if [[ "${match_count}" != "1" ]]; then
    echo "ERROR: Multiple CTs named '${CT_NAME}' were found. Pass --ctid <id>." >&2
    printf '%s\n' "${matches}" >&2
    exit 1
  fi

  CTID="${matches}"
  echo "Discovered CT '${CT_NAME}' as CTID ${CTID}."
}

run_ct() {
  pct exec "${CTID}" -- "$@"
}

run_ct_sh() {
  pct exec "${CTID}" -- sh -c "$1"
}

resolve_ctid

if ! pct status "${CTID}" >/dev/null 2>&1; then
  echo "ERROR: CT ${CTID} was not found or is not accessible." >&2
  exit 1
fi

STATUS="$(pct status "${CTID}" | awk '{print $2}')"
if [[ "${STATUS}" != "running" ]]; then
  echo "ERROR: CT ${CTID} is not running. Current status: ${STATUS}" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/systemd/watchstate-web.service" || ! -f "${REPO_ROOT}/systemd/watchstate-scheduler.service" ]]; then
  echo "ERROR: systemd service templates were not found under ${REPO_ROOT}/systemd." >&2
  exit 1
fi

if [[ "${FORCE}" != "1" ]]; then
  if run_ct test -e /opt/app; then
    echo "ERROR: /opt/app already exists in CT ${CTID}. Use --force only if you intend to reuse/overwrite an existing install." >&2
    exit 1
  fi

  if run_ct test -e /config; then
    echo "ERROR: /config already exists in CT ${CTID}. Use --force only if you intend to reuse/overwrite an existing install." >&2
    exit 1
  fi
fi

echo "Installing OS prerequisites in CT ${CTID}."
run_ct apt update
run_ct apt install -y \
  ca-certificates \
  curl \
  git \
  tar \
  acl \
  unzip \
  rsync \
  redis-server \
  composer \
  php-cli \
  php-curl \
  php-mbstring \
  php-xml \
  php-sqlite3 \
  php-zip \
  php-redis \
  php-intl \
  php-bcmath

echo "Creating WatchState service identity and directories."
run_ct_sh "
set -e
if getent group '${WS_GID}' >/dev/null; then
  existing_group=\$(getent group '${WS_GID}' | cut -d: -f1)
  if [ \"\${existing_group}\" != 'watchstate' ]; then
    echo \"ERROR: GID ${WS_GID} already belongs to group \${existing_group}.\" >&2
    exit 1
  fi
else
  groupadd -g '${WS_GID}' watchstate
fi

if id -u watchstate >/dev/null 2>&1; then
  existing_uid=\$(id -u watchstate)
  if [ \"\${existing_uid}\" != '${WS_UID}' ]; then
    echo \"ERROR: watchstate user exists with UID \${existing_uid}, expected ${WS_UID}.\" >&2
    exit 1
  fi
else
  if getent passwd '${WS_UID}' >/dev/null; then
    existing_user=\$(getent passwd '${WS_UID}' | cut -d: -f1)
    echo \"ERROR: UID ${WS_UID} already belongs to user \${existing_user}.\" >&2
    exit 1
  fi
  useradd -u '${WS_UID}' -g '${WS_GID}' -d /config -s /usr/sbin/nologin watchstate
fi

mkdir -p /opt/bin /config
chown -R watchstate:watchstate /config
"

echo "Installing Bun if missing."
if run_ct_sh 'command -v bun >/dev/null 2>&1'; then
  echo "Bun is already installed."
else
  run_ct_sh "
set -e
curl -fsSL https://bun.sh/install | bash
install -m 0755 /root/.bun/bin/bun /usr/local/bin/bun
bun --version
"
fi

echo "Installing or validating FrankenPHP."
if run_ct test -x /opt/bin/frankenphp; then
  echo "FrankenPHP already exists at /opt/bin/frankenphp."
elif [[ -n "${FRANKENPHP_URL}" ]]; then
  echo "Installing FrankenPHP from explicit binary URL."
  run_ct_sh "
set -e
curl -fsSL '${FRANKENPHP_URL}' -o /opt/bin/frankenphp
chmod 0755 /opt/bin/frankenphp
/opt/bin/frankenphp --version
"
else
  echo "Installing FrankenPHP using official install script: ${FRANKENPHP_INSTALL_SCRIPT}"
  run_ct_sh "
set -e
tmpdir=\$(mktemp -d)
trap 'rm -rf \"\${tmpdir}\"' EXIT
cd \"\${tmpdir}\"
curl -fsSL '${FRANKENPHP_INSTALL_SCRIPT}' | sh

if [ -x ./frankenphp ]; then
  install -m 0755 ./frankenphp /opt/bin/frankenphp
elif command -v frankenphp >/dev/null 2>&1; then
  install -m 0755 \"\$(command -v frankenphp)\" /opt/bin/frankenphp
else
  echo 'ERROR: FrankenPHP installer completed but no frankenphp binary was found.' >&2
  exit 1
fi

/opt/bin/frankenphp --version
"
fi

run_ct /opt/bin/frankenphp --version

echo "Cloning WatchState source."
if run_ct test -d /opt/app/.git; then
  echo "/opt/app already contains a Git work tree. Fetching requested branch."
  run_ct runuser -u watchstate -- sh -c "cd /opt/app && git fetch origin && git checkout '${BRANCH}' && git pull --ff-only origin '${BRANCH}'"
else
  run_ct rm -rf /opt/app
  run_ct runuser -u watchstate -- git clone --branch "${BRANCH}" "${REPO_URL}" /opt/app
fi

run_ct chown -R watchstate:watchstate /opt/app /config

echo "Installing WatchState dependencies and generating frontend."
run_ct runuser -u watchstate -- sh -c "
set -e
cd /opt/app

composer install --no-dev --prefer-dist --optimize-autoloader
composer check-platform-reqs

bun --cwd=./frontend install --frozen-lockfile
composer frontend:gen

rm -rf public/exported
mkdir -p public/exported
rsync -a --delete frontend/exported/ public/exported/
"

echo "Initializing WatchState runtime state."
run_ct runuser -u watchstate -- sh -c "
set -e
cd /opt/app
export WS_DATA_PATH=/config

WS_CACHE_NULL=1 /opt/bin/frankenphp php-cli bin/console -q
/opt/bin/frankenphp php-cli bin/console system:routes
/opt/bin/frankenphp php-cli bin/console events:cache
/opt/bin/frankenphp php-cli bin/console db:legacy --execute
CONTAINER_INIT=1 /opt/bin/frankenphp php-cli bin/console db:migrate --execute --no-interaction
/opt/bin/frankenphp php-cli bin/console db:maintenance
/opt/bin/frankenphp php-cli bin/console db:index
/opt/bin/frankenphp php-cli bin/console system:apikey -q
"

echo "Installing systemd service units."
pct push "${CTID}" "${REPO_ROOT}/systemd/watchstate-web.service" /etc/systemd/system/watchstate-web.service
pct push "${CTID}" "${REPO_ROOT}/systemd/watchstate-scheduler.service" /etc/systemd/system/watchstate-scheduler.service

run_ct systemctl daemon-reload
run_ct systemctl enable --now redis-server.service
run_ct systemctl enable --now watchstate-web.service
run_ct systemctl enable --now watchstate-scheduler.service

echo "Validating installed services."
run_ct systemctl is-active redis-server.service watchstate-web.service watchstate-scheduler.service
run_ct curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck
echo

if [[ "${SKIP_VERIFY}" == "0" ]]; then
  if [[ -x "${SCRIPT_DIR}/verify-watchstate.sh" ]]; then
    echo "Running post-install verification."
    "${SCRIPT_DIR}/verify-watchstate.sh" --ctid "${CTID}"
  else
    echo "WARN: verify script is missing or not executable: ${SCRIPT_DIR}/verify-watchstate.sh" >&2
    echo "WARN: Skipping post-install verification script." >&2
  fi
else
  echo "Skipping post-install verification by request."
fi

echo "Install complete for CT ${CTID}."
