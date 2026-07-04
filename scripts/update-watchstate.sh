#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: update-watchstate.sh [options]

Update the native WatchState LXC deployment from the Proxmox host.

Options:
  --ctid <id>           Proxmox CT ID. Overrides name discovery.
  --name <name>         Proxmox CT name to discover. Default: watchstate
  --branch <branch>     Git branch to fast-forward. Default: master
  --backup-root <path>  Host-side backup root passed to backup script. Default: /root/watchstate-backups
  --skip-backup         Do not run backup-watchstate.sh before updating
  --skip-snapshot       Do not create a Proxmox snapshot before updating
  --skip-verify         Do not run verify-watchstate.sh after updating
  -h, --help            Show this help

Examples:
  ./scripts/update-watchstate.sh
  ./scripts/update-watchstate.sh --name watchstate
  ./scripts/update-watchstate.sh --ctid 103
  ./scripts/update-watchstate.sh --skip-snapshot
USAGE
}

CTID=""
CT_NAME="watchstate"
BRANCH="master"
BACKUP_ROOT="/root/watchstate-backups"
SKIP_BACKUP="0"
SKIP_SNAPSHOT="0"
SKIP_VERIFY="0"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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
    --backup-root)
      BACKUP_ROOT="${2:-}"
      shift 2
      ;;
    --skip-backup)
      SKIP_BACKUP="1"
      shift
      ;;
    --skip-snapshot)
      SKIP_SNAPSHOT="1"
      shift
      ;;
    --skip-verify)
      SKIP_VERIFY="1"
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

if [[ -z "${BRANCH}" ]]; then
  echo "ERROR: --branch cannot be empty." >&2
  exit 2
fi

if [[ -z "${BACKUP_ROOT}" ]]; then
  echo "ERROR: --backup-root cannot be empty." >&2
  exit 2
fi

if [[ -z "${CT_NAME}" && -z "${CTID}" ]]; then
  echo "ERROR: --name cannot be empty when --ctid is not supplied." >&2
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

restart_services() {
  run_ct systemctl start watchstate-web.service >/dev/null 2>&1 || true
  run_ct systemctl start watchstate-scheduler.service >/dev/null 2>&1 || true
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

for tool in git composer bun rsync curl redis-cli; do
  if run_ct_sh "command -v ${tool} >/dev/null 2>&1"; then
    true
  else
    echo "ERROR: Required container tool is missing: ${tool}" >&2
    echo "Install missing prerequisites before updating." >&2
    exit 1
  fi
done

if ! run_ct test -x /opt/bin/frankenphp; then
  echo "ERROR: /opt/bin/frankenphp is missing or not executable." >&2
  exit 1
fi

if ! run_ct id watchstate >/dev/null 2>&1; then
  echo "ERROR: watchstate user is missing in CT ${CTID}." >&2
  exit 1
fi

if [[ "${SKIP_BACKUP}" == "0" ]]; then
  if [[ ! -x "${SCRIPT_DIR}/backup-watchstate.sh" ]]; then
    echo "ERROR: backup script is missing or not executable: ${SCRIPT_DIR}/backup-watchstate.sh" >&2
    echo "Run chmod +x scripts/backup-watchstate.sh or use --skip-backup." >&2
    exit 1
  fi

  echo "Running pre-update backup."
  "${SCRIPT_DIR}/backup-watchstate.sh" --ctid "${CTID}" --backup-root "${BACKUP_ROOT}"
else
  echo "Skipping pre-update backup by request."
fi

if [[ "${SKIP_SNAPSHOT}" == "0" ]]; then
  SNAPSHOT_NAME="watchstate-pre-update-$(date -u +%Y%m%d-%H%M%S)"
  echo "Creating Proxmox snapshot: ${SNAPSHOT_NAME}"
  pct snapshot "${CTID}" "${SNAPSHOT_NAME}" --description "Pre-update WatchState snapshot"
else
  echo "Skipping Proxmox snapshot by request."
fi

trap 'echo "Update failed. Attempting to restart WatchState services." >&2; restart_services' ERR

echo "Stopping WatchState services."
run_ct systemctl stop watchstate-scheduler.service
run_ct systemctl stop watchstate-web.service

echo "Updating WatchState source, dependencies, frontend output, and database state."
run_ct runuser -u watchstate -- sh -c "
set -e
cd /opt/app

git fetch origin
git status --short
git pull --ff-only origin '${BRANCH}'

composer install --no-dev --prefer-dist --optimize-autoloader

bun --cwd=./frontend install --frozen-lockfile
composer frontend:gen

rm -rf public/exported
mkdir -p public/exported
rsync -a --delete frontend/exported/ public/exported/

/opt/bin/frankenphp php-cli bin/console db:migrate --execute --no-interaction
/opt/bin/frankenphp php-cli bin/console db:index
/opt/bin/frankenphp php-cli bin/console events:cache
"

echo "Starting WatchState services."
restart_services
trap - ERR

echo "Validating service state."
run_ct systemctl is-active redis-server.service watchstate-web.service watchstate-scheduler.service
run_ct curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck
echo

if [[ "${SKIP_VERIFY}" == "0" ]]; then
  if [[ -x "${SCRIPT_DIR}/verify-watchstate.sh" ]]; then
    echo "Running post-update verification."
    "${SCRIPT_DIR}/verify-watchstate.sh" --ctid "${CTID}"
  else
    echo "WARN: verify script is missing or not executable: ${SCRIPT_DIR}/verify-watchstate.sh" >&2
    echo "WARN: Skipping post-update verification script." >&2
  fi
else
  echo "Skipping post-update verification by request."
fi

echo "Update complete for CT ${CTID}."
