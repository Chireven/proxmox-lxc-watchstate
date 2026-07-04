#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: backup-watchstate.sh [options]

Create an application-level backup of the native WatchState LXC deployment.

Options:
  --ctid <id>           Proxmox CT ID. Overrides name discovery.
  --name <name>         Proxmox CT name to discover. Default: watchstate
  --backup-root <path>  Host-side backup root. Default: /root/watchstate-backups
  --keep <count>        Keep latest backup directories. Default: 14. Use 0 to disable pruning.
  --list                List matching backup directories and exit
  --prune-only          Prune old backup directories and exit without creating a backup
  --prune-dry-run       Show what pruning would delete without deleting anything
  --no-app              Do not include /opt/app in the backup
  --keep-tmp            Keep temporary archives inside the container for inspection
  -h, --help            Show this help

Examples:
  ./scripts/backup-watchstate.sh
  ./scripts/backup-watchstate.sh --list
  ./scripts/backup-watchstate.sh --keep 30
  ./scripts/backup-watchstate.sh --prune-only --prune-dry-run
  ./scripts/backup-watchstate.sh --name watchstate
  ./scripts/backup-watchstate.sh --ctid 103 --backup-root /mnt/backups/watchstate
  ./scripts/backup-watchstate.sh --no-app
USAGE
}

CTID=""
CT_NAME="watchstate"
BACKUP_ROOT="/root/watchstate-backups"
KEEP_BACKUPS="14"
LIST_ONLY="0"
PRUNE_ONLY="0"
PRUNE_DRY_RUN="0"
INCLUDE_APP="1"
KEEP_TMP="0"
BACKUP_DIR=""

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
    --backup-root)
      BACKUP_ROOT="${2:-}"
      shift 2
      ;;
    --keep)
      KEEP_BACKUPS="${2:-}"
      shift 2
      ;;
    --list)
      LIST_ONLY="1"
      shift
      ;;
    --prune-only)
      PRUNE_ONLY="1"
      shift
      ;;
    --prune-dry-run)
      PRUNE_DRY_RUN="1"
      shift
      ;;
    --no-app)
      INCLUDE_APP="0"
      shift
      ;;
    --keep-tmp)
      KEEP_TMP="1"
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

if [[ -z "${BACKUP_ROOT}" ]]; then
  echo "ERROR: --backup-root cannot be empty." >&2
  exit 2
fi

if [[ -z "${CT_NAME}" && -z "${CTID}" ]]; then
  echo "ERROR: --name cannot be empty when --ctid is not supplied." >&2
  exit 2
fi

if ! [[ "${KEEP_BACKUPS}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --keep must be a non-negative integer." >&2
  exit 2
fi

resolve_backup_root() {
  readlink -m "${BACKUP_ROOT}"
}

validate_backup_root_for_prune() {
  local resolved
  resolved="$(resolve_backup_root)"

  case "${resolved}" in
    /|/root|/home|/mnt|/media|/tmp|/var|/opt|/etc|/usr)
      echo "ERROR: Refusing to prune directly under unsafe backup root: ${resolved}" >&2
      echo "Use a dedicated directory such as /root/watchstate-backups or /mnt/backups/watchstate." >&2
      exit 1
      ;;
  esac
}

list_backup_names() {
  if [[ ! -d "${BACKUP_ROOT}" ]]; then
    return 0
  fi

  find "${BACKUP_ROOT}" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' \
    | grep -E '^[0-9]{8}-[0-9]{6}$' \
    | sort -r || true
}

list_backups() {
  echo "Backup root: ${BACKUP_ROOT}"

  if [[ ! -d "${BACKUP_ROOT}" ]]; then
    echo "No backup root exists yet."
    return 0
  fi

  local found="0"
  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    found="1"
    local path size
    path="${BACKUP_ROOT%/}/${name}"
    size="$(du -sh "${path}" 2>/dev/null | awk '{print $1}' || true)"
    printf '%s\t%s\t%s\n' "${name}" "${size:-unknown}" "${path}"
  done < <(list_backup_names)

  if [[ "${found}" == "0" ]]; then
    echo "No timestamp-style backup directories found."
  fi
}

prune_backups() {
  if [[ "${KEEP_BACKUPS}" == "0" ]]; then
    echo "Backup pruning disabled (--keep 0)."
    return 0
  fi

  validate_backup_root_for_prune

  if [[ ! -d "${BACKUP_ROOT}" ]]; then
    echo "Backup root does not exist; nothing to prune: ${BACKUP_ROOT}"
    return 0
  fi

  mapfile -t backups < <(list_backup_names)

  local total
  total="${#backups[@]}"
  echo "Retention policy: keep latest ${KEEP_BACKUPS} backup(s). Found ${total} backup(s)."

  if (( total <= KEEP_BACKUPS )); then
    echo "No pruning needed."
    return 0
  fi

  local current_name=""
  if [[ -n "${BACKUP_DIR}" ]]; then
    current_name="$(basename "${BACKUP_DIR}")"
  fi

  local idx name path
  for idx in "${!backups[@]}"; do
    if (( idx < KEEP_BACKUPS )); then
      continue
    fi

    name="${backups[$idx]}"
    path="${BACKUP_ROOT%/}/${name}"

    if [[ -n "${current_name}" && "${name}" == "${current_name}" ]]; then
      echo "Skipping current backup directory: ${path}"
      continue
    fi

    if [[ ! "${name}" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
      echo "Skipping non-matching backup directory name: ${path}"
      continue
    fi

    if [[ "${PRUNE_DRY_RUN}" == "1" ]]; then
      echo "Would delete old backup: ${path}"
    else
      echo "Deleting old backup: ${path}"
      rm -rf --one-file-system "${path}"
    fi
  done
}

if [[ "${LIST_ONLY}" == "1" ]]; then
  list_backups
  exit 0
fi

if [[ "${PRUNE_ONLY}" == "1" ]]; then
  prune_backups
  exit 0
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

STAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT%/}/${STAMP}"
mkdir -p "${BACKUP_DIR}"

TMP_FILES=(
  /tmp/watchstate-config.tgz
  /tmp/watchstate-systemd.tgz
  /tmp/watchstate-frankenphp.tgz
)

if [[ "${INCLUDE_APP}" == "1" ]]; then
  TMP_FILES+=(/tmp/watchstate-app.tgz)
fi

cleanup_tmp() {
  if [[ "${KEEP_TMP}" == "0" ]]; then
    pct exec "${CTID}" -- rm -f "${TMP_FILES[@]}" >/dev/null 2>&1 || true
  fi
}

restart_services() {
  pct exec "${CTID}" -- systemctl start watchstate-web.service >/dev/null 2>&1 || true
  pct exec "${CTID}" -- systemctl start watchstate-scheduler.service >/dev/null 2>&1 || true
}

trap 'restart_services; cleanup_tmp' EXIT

echo "Creating WatchState backup for CT ${CTID}."
echo "Backup directory: ${BACKUP_DIR}"

cat > "${BACKUP_DIR}/README.txt" <<EOF
WatchState LXC backup
Timestamp UTC: ${STAMP}
CTID: ${CTID}
CT name: ${CT_NAME}

This backup may contain private application runtime data. Do not commit these archives to Git.
EOF

{
  echo "Backup timestamp UTC: ${STAMP}"
  echo "CTID: ${CTID}"
  echo "CT name: ${CT_NAME}"
  echo
  echo "== Container status =="
  pct status "${CTID}"
  echo
  echo "== Hostname =="
  pct exec "${CTID}" -- hostnamectl || true
  echo
  echo "== Service enabled state =="
  pct exec "${CTID}" -- systemctl is-enabled redis-server.service watchstate-web.service watchstate-scheduler.service || true
  echo
  echo "== Service active state before backup =="
  pct exec "${CTID}" -- systemctl is-active redis-server.service watchstate-web.service watchstate-scheduler.service || true
  echo
  echo "== FrankenPHP version =="
  pct exec "${CTID}" -- /opt/bin/frankenphp --version || true
  echo
  echo "== Redis ping =="
  pct exec "${CTID}" -- redis-cli ping || true
  echo
  echo "== Healthcheck before backup =="
  pct exec "${CTID}" -- curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck || true
} > "${BACKUP_DIR}/metadata-before.txt"

echo "Stopping WatchState services for consistent backup."
pct exec "${CTID}" -- systemctl stop watchstate-scheduler.service
pct exec "${CTID}" -- systemctl stop watchstate-web.service

echo "Creating container-side archives."
pct exec "${CTID}" -- tar --xattrs --acls -czf /tmp/watchstate-config.tgz -C / config
pct exec "${CTID}" -- tar --xattrs --acls -czf /tmp/watchstate-systemd.tgz -C / etc/systemd/system/watchstate-web.service etc/systemd/system/watchstate-scheduler.service
pct exec "${CTID}" -- tar --xattrs --acls -czf /tmp/watchstate-frankenphp.tgz -C / opt/bin/frankenphp

if [[ "${INCLUDE_APP}" == "1" ]]; then
  pct exec "${CTID}" -- tar --xattrs --acls -czf /tmp/watchstate-app.tgz -C / opt/app
fi

echo "Pulling archives to host."
pct pull "${CTID}" /tmp/watchstate-config.tgz "${BACKUP_DIR}/watchstate-config.tgz"
pct pull "${CTID}" /tmp/watchstate-systemd.tgz "${BACKUP_DIR}/watchstate-systemd.tgz"
pct pull "${CTID}" /tmp/watchstate-frankenphp.tgz "${BACKUP_DIR}/watchstate-frankenphp.tgz"

if [[ "${INCLUDE_APP}" == "1" ]]; then
  pct pull "${CTID}" /tmp/watchstate-app.tgz "${BACKUP_DIR}/watchstate-app.tgz"
fi

echo "Restarting WatchState services."
restart_services

{
  echo "Backup timestamp UTC: ${STAMP}"
  echo "CTID: ${CTID}"
  echo "CT name: ${CT_NAME}"
  echo
  echo "== Service active state after backup =="
  pct exec "${CTID}" -- systemctl is-active redis-server.service watchstate-web.service watchstate-scheduler.service
  echo
  echo "== Healthcheck after backup =="
  pct exec "${CTID}" -- curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck
  echo
  echo "== Archive listing =="
  ls -lh "${BACKUP_DIR}"
} > "${BACKUP_DIR}/metadata-after.txt"

cleanup_tmp
trap - EXIT

echo "Validating post-backup service state."
pct exec "${CTID}" -- systemctl is-active redis-server.service watchstate-web.service watchstate-scheduler.service
pct exec "${CTID}" -- curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck
echo

prune_backups

echo "Backup complete: ${BACKUP_DIR}"
