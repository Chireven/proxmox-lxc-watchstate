#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: verify-watchstate.sh [options]

Verify the native WatchState LXC deployment from the Proxmox host.

Options:
  --ctid <id>      Proxmox CT ID. Default: 103
  --json           Emit a compact JSON-like summary at the end
  -h, --help       Show this help

Examples:
  ./scripts/verify-watchstate.sh
  ./scripts/verify-watchstate.sh --ctid 103
USAGE
}

CTID="103"
EMIT_JSON="0"
FAILURES=0
WARNINGS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ctid)
      CTID="${2:-}"
      shift 2
      ;;
    --json)
      EMIT_JSON="1"
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

if [[ -z "${CTID}" ]]; then
  echo "ERROR: --ctid cannot be empty." >&2
  exit 2
fi

pass() {
  echo "PASS: $*"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  echo "WARN: $*"
}

fail() {
  FAILURES=$((FAILURES + 1))
  echo "FAIL: $*"
}

section() {
  echo
  echo "== $* =="
}

run_ct() {
  pct exec "${CTID}" -- "$@"
}

run_ct_sh() {
  pct exec "${CTID}" -- sh -c "$1"
}

check_host() {
  section "Host checks"

  if command -v pct >/dev/null 2>&1; then
    pass "pct is available"
  else
    echo "ERROR: pct was not found. Run this script on the Proxmox host." >&2
    exit 1
  fi

  if pct status "${CTID}" >/dev/null 2>&1; then
    pass "CT ${CTID} exists"
  else
    echo "ERROR: CT ${CTID} was not found or is not accessible." >&2
    exit 1
  fi

  local status
  status="$(pct status "${CTID}" | awk '{print $2}')"
  if [[ "${status}" == "running" ]]; then
    pass "CT ${CTID} is running"
  else
    echo "ERROR: CT ${CTID} is not running. Current status: ${status}" >&2
    exit 1
  fi
}

check_identity_and_paths() {
  section "Identity and path checks"

  if run_ct id watchstate >/dev/null 2>&1; then
    pass "watchstate user exists"
  else
    fail "watchstate user is missing"
  fi

  if run_ct getent group watchstate >/dev/null 2>&1; then
    pass "watchstate group exists"
  else
    fail "watchstate group is missing"
  fi

  for path in /config /config/config /config/db /opt/app /opt/app/public/exported /opt/bin/frankenphp; do
    if run_ct test -e "${path}"; then
      pass "${path} exists"
    else
      fail "${path} is missing"
    fi
  done

  if run_ct test -x /opt/bin/frankenphp; then
    pass "/opt/bin/frankenphp is executable"
  else
    fail "/opt/bin/frankenphp is not executable"
  fi

  local config_owner app_owner
  config_owner="$(run_ct stat -c '%U:%G' /config 2>/dev/null || true)"
  app_owner="$(run_ct stat -c '%U:%G' /opt/app 2>/dev/null || true)"

  if [[ "${config_owner}" == "watchstate:watchstate" ]]; then
    pass "/config owner is watchstate:watchstate"
  else
    fail "/config owner is ${config_owner:-unknown}, expected watchstate:watchstate"
  fi

  if [[ "${app_owner}" == "watchstate:watchstate" ]]; then
    pass "/opt/app owner is watchstate:watchstate"
  else
    fail "/opt/app owner is ${app_owner:-unknown}, expected watchstate:watchstate"
  fi
}

check_services() {
  section "Service checks"

  for svc in redis-server.service watchstate-web.service watchstate-scheduler.service; do
    if run_ct systemctl is-enabled "${svc}" >/dev/null 2>&1; then
      pass "${svc} is enabled"
    else
      fail "${svc} is not enabled"
    fi

    if run_ct systemctl is-active "${svc}" >/dev/null 2>&1; then
      pass "${svc} is active"
    else
      fail "${svc} is not active"
    fi
  done
}

check_runtime() {
  section "Runtime checks"

  if run_ct /opt/bin/frankenphp --version >/dev/null 2>&1; then
    pass "FrankenPHP runs"
    run_ct /opt/bin/frankenphp --version || true
  else
    fail "FrankenPHP version check failed"
  fi

  if run_ct redis-cli ping | grep -qx 'PONG'; then
    pass "Redis ping returns PONG"
  else
    fail "Redis ping did not return PONG"
  fi

  local health
  health="$(run_ct curl -fsS http://127.0.0.1:8080/v1/api/system/healthcheck 2>/dev/null || true)"
  if [[ "${health}" == *'"status":"ok"'* ]]; then
    pass "WatchState healthcheck is healthy"
    echo "${health}"
  else
    fail "WatchState healthcheck failed or was unexpected: ${health:-empty response}"
  fi
}

check_app_state() {
  section "Application state checks"

  if run_ct_sh 'cd /opt/app && runuser -u watchstate -- git rev-parse --is-inside-work-tree' | grep -qx 'true'; then
    pass "/opt/app is a Git work tree"
  else
    fail "/opt/app is not a valid Git work tree for watchstate"
  fi

  local branch commit remote status
  branch="$(run_ct_sh 'cd /opt/app && runuser -u watchstate -- git branch --show-current' 2>/dev/null || true)"
  commit="$(run_ct_sh 'cd /opt/app && runuser -u watchstate -- git rev-parse HEAD' 2>/dev/null || true)"
  remote="$(run_ct_sh 'cd /opt/app && runuser -u watchstate -- git remote get-url origin' 2>/dev/null || true)"
  status="$(run_ct_sh 'cd /opt/app && runuser -u watchstate -- git status --short' 2>/dev/null || true)"

  echo "branch: ${branch:-unknown}"
  echo "commit: ${commit:-unknown}"
  echo "origin: ${remote:-unknown}"

  if [[ "${branch}" == "master" ]]; then
    pass "Git branch is master"
  else
    warn "Git branch is ${branch:-unknown}, expected master"
  fi

  if [[ "${remote}" == "https://github.com/arabcoders/watchstate.git" ]]; then
    pass "Git origin matches upstream WatchState"
  else
    warn "Git origin is ${remote:-unknown}"
  fi

  local unexpected_status
  unexpected_status="$(printf '%s\n' "${status}" | grep -v '^?? public/exported/$' || true)"
  if [[ -z "${unexpected_status}" ]]; then
    pass "Git status is clean except expected generated public/exported output"
  else
    warn "Git status contains unexpected entries:"
    printf '%s\n' "${unexpected_status}"
  fi

  local exported_size
  exported_size="$(run_ct_sh 'du -sh /opt/app/public/exported 2>/dev/null | awk "{print \$1}"' || true)"
  if [[ -n "${exported_size}" ]]; then
    pass "/opt/app/public/exported is populated (${exported_size})"
  else
    fail "/opt/app/public/exported is missing or empty"
  fi
}

check_tools() {
  section "Tool checks"

  for tool in git composer bun rsync curl redis-cli; do
    if run_ct_sh "command -v ${tool} >/dev/null 2>&1"; then
      pass "${tool} is available"
    else
      fail "${tool} is missing"
    fi
  done

  if run_ct_sh 'cd /opt/app && runuser -u watchstate -- composer check-platform-reqs >/dev/null 2>&1'; then
    pass "Composer platform requirements pass under system PHP"
  else
    warn "Composer platform requirement check under system PHP failed"
  fi

  if run_ct_sh 'cd /opt/app && runuser -u watchstate -- /opt/bin/frankenphp php-cli /bin/composer check-platform-reqs >/dev/null 2>&1'; then
    pass "Composer platform requirements pass under FrankenPHP"
  else
    warn "Composer platform requirement check under FrankenPHP failed"
  fi
}

check_database() {
  section "Database checks"

  if run_ct test -f /config/db/watchstate_v02.db; then
    local db_size
    db_size="$(run_ct stat -c '%s' /config/db/watchstate_v02.db 2>/dev/null || true)"
    pass "WatchState database exists (${db_size:-unknown} bytes)"
  else
    fail "WatchState database /config/db/watchstate_v02.db is missing"
  fi

  if run_ct_sh 'cd /opt/app && runuser -u watchstate -- /opt/bin/frankenphp php-cli bin/console db:migrate --no-interaction >/tmp/watchstate-verify-migrate.txt 2>&1'; then
    local migrate_output
    migrate_output="$(run_ct cat /tmp/watchstate-verify-migrate.txt 2>/dev/null || true)"
    if printf '%s\n' "${migrate_output}" | grep -qi 'Would apply'; then
      warn "db:migrate dry-run reports pending migrations"
      printf '%s\n' "${migrate_output}"
    else
      pass "db:migrate dry-run reports no pending migration action"
      printf '%s\n' "${migrate_output}"
    fi
    run_ct rm -f /tmp/watchstate-verify-migrate.txt >/dev/null 2>&1 || true
  else
    fail "db:migrate dry-run failed"
  fi
}

check_host
check_identity_and_paths
check_services
check_runtime
check_app_state
check_tools
check_database

section "Summary"
echo "Warnings: ${WARNINGS}"
echo "Failures: ${FAILURES}"

if [[ "${EMIT_JSON}" == "1" ]]; then
  printf '{"ctid":"%s","warnings":%s,"failures":%s}\n' "${CTID}" "${WARNINGS}" "${FAILURES}"
fi

if [[ "${FAILURES}" -gt 0 ]]; then
  echo "Verification failed. Review FAIL entries above." >&2
  exit 1
fi

if [[ "${WARNINGS}" -gt 0 ]]; then
  echo "Verification completed with warnings. Review WARN entries above."
  exit 0
fi

echo "Verification passed."
