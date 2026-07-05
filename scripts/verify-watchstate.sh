#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: verify-watchstate.sh [options]

Verify the native WatchState LXC deployment from the Proxmox host.

Options:
  --ctid <id>            Proxmox CT ID. Overrides name discovery.
  --name <name>          Proxmox CT name to discover. Default: watchstate
  --json                 Emit a compact JSON-like summary at the end
  --support-bundle       Include sanitized backend diagnostics for public support
  --backend-diagnostics  Alias for --support-bundle
  --no-sanitize          Do not sanitize support-bundle backend names, URLs, or users
  --no-color             Disable colored output
  -h, --help             Show this help

Examples:
  ./scripts/verify-watchstate.sh
  ./scripts/verify-watchstate.sh --name watchstate
  ./scripts/verify-watchstate.sh --ctid 103
  ./scripts/verify-watchstate.sh --ctid 103 --support-bundle
USAGE
}

CTID=""
CT_NAME="watchstate"
EMIT_JSON="0"
NO_COLOR_OUTPUT="0"
SUPPORT_BUNDLE="0"
SANITIZE_SUPPORT="1"
FAILURES=0
WARNINGS=0
PASSES=0

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
    --json)
      EMIT_JSON="1"
      shift
      ;;
    --support-bundle|--backend-diagnostics)
      SUPPORT_BUNDLE="1"
      shift
      ;;
    --no-sanitize)
      SANITIZE_SUPPORT="0"
      shift
      ;;
    --no-color)
      NO_COLOR_OUTPUT="1"
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

if [[ -t 1 && "${NO_COLOR_OUTPUT}" != "1" && -z "${NO_COLOR:-}" ]]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  CYAN=$'\033[36m'
  RESET=$'\033[0m'
else
  BOLD=""
  DIM=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  CYAN=""
  RESET=""
fi

hr() {
  printf '%s\n' "${DIM}────────────────────────────────────────────────────────────${RESET}"
}

banner() {
  echo
  hr
  printf '%b\n' "${BOLD}${CYAN}WatchState LXC Verification${RESET}"
  printf '%b\n' "${DIM}Target: CT ${CTID:-${CT_NAME}}${RESET}"
  hr
}

pass() {
  PASSES=$((PASSES + 1))
  printf '%b\n' "${GREEN}PASS${RESET}  $*"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  printf '%b\n' "${YELLOW}WARN${RESET}  $*"
}

fail() {
  FAILURES=$((FAILURES + 1))
  printf '%b\n' "${RED}FAIL${RESET}  $*"
}

info() {
  printf '%b\n' "${DIM}INFO${RESET}  $*"
}

section() {
  echo
  printf '%b\n' "${BOLD}${BLUE}== $* ==${RESET}"
}

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
  info "Discovered CT '${CT_NAME}' as CTID ${CTID}."
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

  resolve_ctid

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
    info "${health}"
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

  info "branch: ${branch:-unknown}"
  info "commit: ${commit:-unknown}"
  info "origin: ${remote:-unknown}"

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

  for tool in git composer rsync curl redis-cli; do
    if run_ct_sh "command -v ${tool} >/dev/null 2>&1"; then
      pass "${tool} is available"
    else
      fail "${tool} is missing"
    fi
  done

  if run_ct test -x /usr/local/bin/bun; then
    pass "bun is available at /usr/local/bin/bun"
    run_ct /usr/local/bin/bun --version || true
  else
    fail "bun is missing at /usr/local/bin/bun"
  fi

  if run_ct_sh 'cd /opt/app && runuser -u watchstate -- sh -c "export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin; composer check-platform-reqs >/dev/null 2>&1"'; then
    pass "Composer platform requirements pass under system PHP"
  else
    warn "Composer platform requirement check under system PHP failed"
  fi

  if run_ct_sh 'cd /opt/app && runuser -u watchstate -- sh -c "export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin; /opt/bin/frankenphp php-cli /bin/composer check-platform-reqs >/dev/null 2>&1"'; then
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

write_support_bundle_helper() {
  run_ct_sh "cat > /tmp/watchstate-support-bundle.php" <<'PHP'
<?php
declare(strict_types=1);

$sanitize = getenv('WS_VERIFY_SANITIZE') !== '0';
$serversFile = '/config/config/servers.yaml';
$autoload = '/opt/app/vendor/autoload.php';
$dbFile = '/config/db/watchstate_v02.db';

function out(string $line = ''): void { echo $line . PHP_EOL; }
function stamp(mixed $value): string {
    if (null === $value || '' === $value || false === $value) { return 'never'; }
    if (is_numeric($value) && (int) $value <= 0) { return 'never'; }
    if (is_numeric($value)) { return date('c', (int) $value); }
    return (string) $value;
}
function getv(array $array, string $path, mixed $default = null): mixed {
    $current = $array;
    foreach (explode('.', $path) as $part) {
        if (!is_array($current) || !array_key_exists($part, $current)) { return $default; }
        $current = $current[$part];
    }
    return $current;
}

$maps = [];
function placeholder(string $kind, mixed $value): string {
    global $sanitize, $maps;
    $value = trim((string) $value);
    if ('' === $value) { return '<empty>'; }
    if (!$sanitize) { return $value; }
    if (!isset($maps[$kind])) { $maps[$kind] = []; }
    if (!isset($maps[$kind][$value])) { $maps[$kind][$value] = '<' . $kind . '-' . (count($maps[$kind]) + 1) . '>'; }
    return $maps[$kind][$value];
}
function backend_label(string $type, mixed $name): string {
    $type = preg_replace('/[^a-z0-9]+/', '-', strtolower('' === (string) $type ? 'backend' : (string) $type));
    return placeholder($type . '-backend', $name);
}
function identity_label(mixed $user): string { return placeholder('identity', $user); }
function token_state(mixed $token): string { return '' === trim((string) $token) ? 'missing' : 'present'; }
function safe_url(mixed $url, string $label): string {
    global $sanitize;
    $url = trim((string) $url);
    if ('' === $url) { return '<empty>'; }
    if (!$sanitize) { return $url; }
    $parts = parse_url($url);
    if (!is_array($parts) || empty($parts['scheme'])) { return '<url-for-' . trim($label, '<>') . '>'; }
    $port = isset($parts['port']) ? ':' . $parts['port'] : '';
    return $parts['scheme'] . '://<url-for-' . trim($label, '<>') . '>' . $port;
}
function normalize_servers(mixed $servers): array {
    if (!is_array($servers)) { return []; }
    $normalized = [];
    foreach ($servers as $key => $value) {
        if (!is_array($value)) { continue; }
        if (!array_key_exists('name', $value) && is_string($key)) { $value['name'] = $key; }
        $normalized[] = $value;
    }
    return $normalized;
}
function probe_backend(mixed $url, mixed $type): string {
    $url = trim((string) $url);
    $type = strtolower((string) $type);
    if ('' === $url) { return 'skipped-empty-url'; }
    $target = rtrim($url, '/');
    if ('plex' === $type) { $target .= '/identity'; }
    $context = stream_context_create(['http' => ['timeout' => 4, 'ignore_errors' => true], 'ssl' => ['verify_peer' => false, 'verify_peer_name' => false]]);
    $result = @file_get_contents($target, false, $context);
    if (false === $result) { return 'failed'; }
    return 'ok';
}
function relationship_reason(bool $leftToRight, bool $rightToLeft, array $left, array $right): string {
    if ($leftToRight && $rightToLeft) { return 'bidirectional-import-export-enabled'; }
    if ($leftToRight) { return 'left-imports-and-right-exports'; }
    if ($rightToLeft) { return 'right-imports-and-left-exports'; }
    $reasons = [];
    if (!$left['import'] && !$right['import']) { $reasons[] = 'imports-disabled'; }
    if (!$left['export'] && !$right['export']) { $reasons[] = 'exports-disabled'; }
    if ($left['import'] && !$right['export']) { $reasons[] = 'left-import-enabled-but-right-export-disabled'; }
    if ($right['import'] && !$left['export']) { $reasons[] = 'right-import-enabled-but-left-export-disabled'; }
    return implode(',', array_unique($reasons)) ?: 'no-compatible-import-export-path';
}
function relationship_symbol(bool $leftToRight, bool $rightToLeft): string {
    if ($leftToRight && $rightToLeft) { return '<>'; }
    if ($leftToRight) { return '>'; }
    if ($rightToLeft) { return '<'; }
    return 'x';
}
function q(PDO $pdo, string $sql, array $params = []): mixed {
    try {
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable) {
        return null;
    }
}
function quote_identifier(string $identifier): string {
    return '"' . str_replace('"', '""', $identifier) . '"';
}
function table_columns(PDO $pdo, string $table): array {
    $rows = q($pdo, 'PRAGMA table_info(' . quote_identifier($table) . ')');
    if (!is_array($rows)) { return []; }
    return array_map(static fn(array $row): string => (string) $row['name'], $rows);
}
function count_query(PDO $pdo, string $table, string $where = '', array $params = []): int {
    $sql = 'SELECT COUNT(*) AS c FROM ' . quote_identifier($table) . ('' !== $where ? ' WHERE ' . $where : '');
    $rows = q($pdo, $sql, $params);
    if (!is_array($rows) || !isset($rows[0]['c'])) { return 0; }
    return (int) $rows[0]['c'];
}
function max_timestamp(PDO $pdo, string $table, array $columns): string {
    foreach (['updated_at', 'updated', 'created_at'] as $column) {
        if (!in_array($column, $columns, true)) { continue; }
        $rows = q($pdo, 'SELECT MAX(' . quote_identifier($column) . ') AS m FROM ' . quote_identifier($table));
        if (is_array($rows) && isset($rows[0]['m'])) { return stamp($rows[0]['m']); }
    }
    return 'unknown';
}

out('Support bundle mode: ' . ($sanitize ? 'sanitized' : 'unsanitized'));
out('Source: /config/config/servers.yaml');

if (!file_exists($serversFile)) {
    out('Backend Summary');
    out('- servers.yaml not found; no configured backends discovered from config file');
    exit(0);
}

if (!file_exists($autoload)) {
    out('Backend Summary');
    out('- vendor autoload not found; cannot parse servers.yaml');
    exit(0);
}

require $autoload;

try {
    $servers = Symfony\Component\Yaml\Yaml::parseFile($serversFile);
} catch (Throwable $e) {
    out('Backend Summary');
    out('- failed to parse servers.yaml: ' . $e->getMessage());
    exit(0);
}

$backends = normalize_servers($servers);
if (0 === count($backends)) {
    out('Backend Summary');
    out('- no configured backends found in servers.yaml');
    exit(0);
}

$summary = [];
$importCount = 0;
$exportCount = 0;
$reachableCount = 0;
$rawToLabel = [];

out('Backend Summary');
foreach ($backends as $backend) {
    $name = (string) getv($backend, 'name', 'unknown');
    $type = (string) getv($backend, 'type', 'unknown');
    $label = backend_label($type, $name);
    $rawToLabel[$name] = $label;
    $user = identity_label(getv($backend, 'user', 'unknown'));
    $url = safe_url(getv($backend, 'url', ''), $label);
    $importEnabled = filter_var(getv($backend, 'import.enabled', false), FILTER_VALIDATE_BOOLEAN);
    $exportEnabled = filter_var(getv($backend, 'export.enabled', false), FILTER_VALIDATE_BOOLEAN);
    $reachability = probe_backend(getv($backend, 'url', ''), $type);

    if ($importEnabled) { $importCount++; }
    if ($exportEnabled) { $exportCount++; }
    if ('ok' === $reachability) { $reachableCount++; }

    $summary[] = [
        'raw_name' => $name,
        'label' => $label,
        'type' => $type,
        'user' => $user,
        'import' => $importEnabled,
        'export' => $exportEnabled,
        'reachability' => $reachability,
    ];

    out(sprintf(
        '- %s type=%s url=%s user=%s token=%s import=%s export=%s last_import=%s last_export=%s reachability=%s',
        $label,
        $type,
        $url,
        $user,
        token_state(getv($backend, 'token', '')),
        $importEnabled ? 'enabled' : 'disabled',
        $exportEnabled ? 'enabled' : 'disabled',
        stamp(getv($backend, 'import.lastSync')),
        stamp(getv($backend, 'export.lastSync')),
        $reachability
    ));
}

out('');
out('Identity Sync Relationships');
out('- source=inferred-from-config note=direction-requires-source-import-and-target-export');
$relationshipCount = 0;
$activeRelationshipCount = 0;
for ($i = 0; $i < count($summary); $i++) {
    for ($j = $i + 1; $j < count($summary); $j++) {
        $left = $summary[$i];
        $right = $summary[$j];
        if ($left['user'] !== $right['user']) { continue; }
        $leftToRight = true === $left['import'] && true === $right['export'];
        $rightToLeft = true === $right['import'] && true === $left['export'];
        $symbol = relationship_symbol($leftToRight, $rightToLeft);
        $reason = relationship_reason($leftToRight, $rightToLeft, $left, $right);
        if ('x' !== $symbol) { $activeRelationshipCount++; }
        $relationshipCount++;
        out(sprintf('- %s\\%s  %s  %s\\%s reason=%s', $left['label'], $left['user'], $symbol, $right['label'], $right['user'], $reason));
    }
}
if (0 === $relationshipCount) {
    out('- no same-identity backend pairs discovered');
}

out('');
out('Operational Statistics');
$stateStatsFound = false;
if (!file_exists($dbFile)) {
    out('- database=missing path=/config/db/watchstate_v02.db');
} else {
    try {
        $pdo = new PDO('sqlite:' . $dbFile);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $tables = q($pdo, "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name");
        $tableNames = is_array($tables) ? array_map(static fn(array $row): string => (string) $row['name'], $tables) : [];
        out('- database=present tables=' . count($tableNames));

        foreach ($tableNames as $table) {
            $columns = table_columns($pdo, $table);
            $hasStateColumns = in_array('via', $columns, true) && in_array('watched', $columns, true) && in_array('type', $columns, true);
            if (!$hasStateColumns) { continue; }

            $stateStatsFound = true;
            $total = count_query($pdo, $table);
            $watched = count_query($pdo, $table, 'watched > 0');
            $unwatched = count_query($pdo, $table, 'watched = 0 OR watched IS NULL');
            $updated = max_timestamp($pdo, $table, $columns);
            out(sprintf('- state_table=%s total=%d watched=%d unwatched=%d latest_update=%s', $table, $total, $watched, $unwatched, $updated));

            $byType = q($pdo, 'SELECT type, COUNT(*) AS c FROM ' . quote_identifier($table) . ' GROUP BY type ORDER BY c DESC');
            if (is_array($byType)) {
                foreach ($byType as $row) {
                    out(sprintf('  type=%s count=%d', (string) $row['type'], (int) $row['c']));
                }
            }

            $byBackend = q($pdo, 'SELECT via, COUNT(*) AS total, SUM(CASE WHEN watched > 0 THEN 1 ELSE 0 END) AS watched, MAX(COALESCE(NULLIF(updated_at, 0), NULLIF(updated, 0), created_at)) AS latest FROM ' . quote_identifier($table) . ' GROUP BY via ORDER BY total DESC');
            if (is_array($byBackend)) {
                foreach ($byBackend as $row) {
                    $rawVia = (string) ($row['via'] ?? 'unknown');
                    $label = $rawToLabel[$rawVia] ?? placeholder('state-backend', $rawVia);
                    out(sprintf('  backend=%s total=%d watched=%d latest=%s', $label, (int) $row['total'], (int) $row['watched'], stamp($row['latest'] ?? null)));
                }
            }
        }

        if (!$stateStatsFound) {
            out('- state_stats=not-found reason=no-table-with-via-watched-type-columns-discovered');
        }
    } catch (Throwable $e) {
        out('- database_stats=failed reason=' . $e->getMessage());
    }
}

out('');
out('Readiness Findings');
out(sprintf('- configured_backends=%d import_enabled=%d export_enabled=%d reachable=%d', count($summary), $importCount, $exportCount, $reachableCount));
out(sprintf('- identity_relationships=%d active_identity_relationships=%d', $relationshipCount, $activeRelationshipCount));
if (count($summary) < 2) {
    out('- sync_validation=not-ready reason=at-least-two-backends-are-needed-for-backend-to-backend-sync');
}
if ($importCount < 1) {
    out('- import_validation=not-ready reason=no-import-enabled-backend-found');
}
if ($exportCount < 1) {
    out('- export_validation=not-ready reason=no-export-enabled-backend-found');
}
if ($relationshipCount > 0 && $activeRelationshipCount < 1) {
    out('- relationship_validation=not-ready reason=no-active-import-to-export-identity-relationship');
}
if ($stateStatsFound) {
    out('- state_database=present reason=imported-state-statistics-discovered');
} else {
    out('- state_database=review reason=no-imported-state-statistics-discovered');
}
if ($reachableCount < count($summary)) {
    out('- reachability=review reason=one-or-more-backends-did-not-respond-to-basic-probe');
}
if (count($summary) >= 2 && $importCount >= 1 && $exportCount >= 1 && $activeRelationshipCount >= 1) {
    out('- sync_validation=ready-for-manual-watched-state-test');
}

out('');
out('Possible Sync Topology');
$edges = 0;
foreach ($summary as $source) {
    if (true !== $source['import']) { continue; }
    foreach ($summary as $target) {
        if ($source['label'] === $target['label']) { continue; }
        if (true !== $target['export']) { continue; }
        if ($source['user'] !== $target['user']) { continue; }
        out(sprintf('- %s/%s -> %s/%s', $source['label'], $source['user'], $target['label'], $target['user']));
        $edges++;
    }
}
if (0 === $edges) {
    out('- no same-identity import-to-export paths inferred from configured backends');
}

out('');
out('Sanitization Map');
if ($sanitize) {
    foreach ($maps as $kind => $items) {
        out('- ' . $kind . ': ' . count($items) . ' value(s) redacted');
    }
} else {
    out('- disabled by --no-sanitize');
}
PHP
}

check_support_bundle() {
  if [[ "${SUPPORT_BUNDLE}" != "1" ]]; then
    return
  fi

  section "Backend support bundle"

  if [[ "${SANITIZE_SUPPORT}" == "1" ]]; then
    info "Sanitization is enabled. Output is intended to be safe for public support review, but review before posting."
  else
    warn "Sanitization is disabled. Output may include private backend names, URLs, and users."
  fi

  if ! run_ct test -f /config/config/servers.yaml; then
    warn "/config/config/servers.yaml was not found; no backend topology can be reported"
    return
  fi

  if ! run_ct test -f /opt/app/vendor/autoload.php; then
    warn "/opt/app/vendor/autoload.php was not found; cannot parse backend configuration"
    return
  fi

  write_support_bundle_helper
  if run_ct_sh "WS_VERIFY_SANITIZE=${SANITIZE_SUPPORT} /opt/bin/frankenphp php-cli /tmp/watchstate-support-bundle.php"; then
    pass "Backend support bundle generated"
  else
    warn "Backend support bundle generation failed"
  fi
  run_ct rm -f /tmp/watchstate-support-bundle.php >/dev/null 2>&1 || true
}

print_summary() {
  section "Summary"
  hr
  printf '%b\n' "${GREEN}Passes:${RESET}   ${PASSES}"
  printf '%b\n' "${YELLOW}Warnings:${RESET} ${WARNINGS}"
  printf '%b\n' "${RED}Failures:${RESET} ${FAILURES}"
  hr

  if [[ "${EMIT_JSON}" == "1" ]]; then
    printf '{"ctid":"%s","name":"%s","passes":%s,"warnings":%s,"failures":%s,"support_bundle":%s,"sanitized":%s}\n' "${CTID}" "${CT_NAME}" "${PASSES}" "${WARNINGS}" "${FAILURES}" "${SUPPORT_BUNDLE}" "${SANITIZE_SUPPORT}"
  fi
}

check_host
banner
check_identity_and_paths
check_services
check_runtime
check_app_state
check_tools
check_database
check_support_bundle
print_summary

if [[ "${FAILURES}" -gt 0 ]]; then
  printf '%b\n' "${RED}${BOLD}Verification failed. Review FAIL entries above.${RESET}" >&2
  exit 1
fi

if [[ "${WARNINGS}" -gt 0 ]]; then
  printf '%b\n' "${YELLOW}${BOLD}Verification completed with warnings. Review WARN entries above.${RESET}"
  exit 0
fi

printf '%b\n' "${GREEN}${BOLD}Verification passed.${RESET}"
