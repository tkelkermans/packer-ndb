#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# shellcheck source=scripts/prism.sh
source "$ROOT_DIR/scripts/prism.sh"

TARGETS_FILE=${NDB_E2E_TARGETS_FILE:-/private/tmp/ndb_e2e_latest_targets.psv}
STATE_DIR=${NDB_E2E_STATE_DIR:-/private/tmp/ndb_e2e_state}
EVIDENCE_FILE=${NDB_E2E_EVIDENCE_FILE:-/private/tmp/ndb_e2e_results.jsonl}
LIMIT=0
DB_TYPE_FILTER=""
ROW_FILTER=""
DRY_RUN=false
RERUN_PASSED=false
PREFLIGHT_IMAGES=false
DELETE_VM_ON_FAILURE=${NDB_E2E_DELETE_VM_ON_FAILURE:-false}
CURRENT_STATE_FILE=""
ERROR_RECORDED=false
OPERATION_MAX_POLLS=${NDB_E2E_OPERATION_MAX_POLLS:-360}
OPERATION_POLL_SECONDS=${NDB_E2E_OPERATION_POLL_SECONDS:-10}
OPERATION_STALL_POLLS=${NDB_E2E_OPERATION_STALL_POLLS:-120}
NDB_API_TIMEOUT=${NDB_E2E_NDB_API_TIMEOUT:-300}
SOURCE_VM_MAX_ATTEMPTS=${NDB_E2E_SOURCE_VM_MAX_ATTEMPTS:-3}
SSH_MAX_POLLS=${NDB_E2E_SSH_MAX_POLLS:-30}
GUEST_READY_MAX_POLLS=${NDB_E2E_GUEST_READY_MAX_POLLS:-90}
TARGET_OBSERVER=${NDB_E2E_TARGET_OBSERVER:-false}
TARGET_OBSERVER_INTERVAL_SECONDS=${NDB_E2E_TARGET_OBSERVER_INTERVAL_SECONDS:-10}
TARGET_OBSERVER_MAX_SECONDS=${NDB_E2E_TARGET_OBSERVER_MAX_SECONDS:-900}
TARGET_OBSERVER_PID=""

NDB_CLUSTER_ID=${NDB_E2E_CLUSTER_ID:-8c4a628f-d3a1-4ef2-b771-c92e20420824}
NDB_POSTGRES_NETWORK_PROFILE_ID=${NDB_E2E_POSTGRES_NETWORK_PROFILE_ID:-${NDB_E2E_NETWORK_PROFILE_ID:-97a2d940-9aa7-4e77-8d54-2f64268635f1}}
NDB_MONGODB_NETWORK_PROFILE_ID=${NDB_E2E_MONGODB_NETWORK_PROFILE_ID:-}
NDB_POSTGRES_DB_PARAM_PROFILE_ID=${NDB_E2E_POSTGRES_DB_PARAM_PROFILE_ID:-45549e8a-d3fc-4128-87f6-c8d8f4136ddf}
NDB_MONGODB_DB_PARAM_PROFILE_ID=${NDB_E2E_MONGODB_DB_PARAM_PROFILE_ID:-9c9dcaad-cf15-4a2e-9878-1f26353e7884}
NDB_COMPUTE_PROFILE_ID=${NDB_E2E_COMPUTE_PROFILE_ID:-0227836b-c7ef-4d8b-bdcd-f309191fb15c}
NDB_SLA_ID=${NDB_E2E_SLA_ID:-de4b96d6-420c-4f2b-98c6-88bd8f4dddcc}
NDB_POSTGRES_SOFTWARE_HOME_BASE=${NDB_E2E_POSTGRES_SOFTWARE_HOME_BASE:-/opt/ndb/postgresql}
NDB_POSTGRES_SOFTWARE_DISK_SIZE_GB=${NDB_E2E_POSTGRES_SOFTWARE_DISK_SIZE_GB:-10}
NDB_MONGODB_SOFTWARE_HOME=${NDB_E2E_MONGODB_SOFTWARE_HOME:-/opt/ndb/mongodb}

PRIVATE_KEY_PATH=${NDB_ARTIFACT_PRIVATE_KEY_PATH:-$ROOT_DIR/packer/id_rsa}
PUBLIC_KEY_PATH=${NDB_ARTIFACT_PUBLIC_KEY_PATH:-$ROOT_DIR/packer/id_rsa.pub}
USER_DATA_TEMPLATE=${NDB_E2E_USER_DATA_TEMPLATE:-$ROOT_DIR/packer/http/e2e-user-data}

usage() {
  cat <<'EOF'
Usage: scripts/ndb_e2e_validate.sh [options]

Runs serialized NDB software-profile and database-provisioning validation from
the latest successful image manifest per buildable matrix row.

Options:
  --db-type pgsql|mongodb  Limit rows by database type
  --row-id ID              Run one row id from the generated targets
  --limit N                Stop after N attempted rows
  --dry-run                Print selected rows without calling Prism or NDB
  --preflight-images       Check selected Prism images exist and exit
  --rerun-passed           Do not skip rows already marked pass in evidence
  -h, --help               Show this help

Environment:
  Run through: op run --env-file=.env -- scripts/ndb_e2e_validate.sh ...
  NDB_E2E_POSTGRES_SOFTWARE_HOME_BASE defaults to /opt/ndb/postgresql.
  NDB_E2E_POSTGRES_SOFTWARE_DISK_SIZE_GB defaults to 10.
  NDB_E2E_NDB_API_TIMEOUT defaults to 300 seconds.
  NDB_E2E_TARGET_OBSERVER=true captures best-effort target diagnostics during provision.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-type)
      DB_TYPE_FILTER=$2
      shift 2
      ;;
    --row-id)
      ROW_FILTER=$2
      shift 2
      ;;
    --limit)
      LIMIT=$2
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --preflight-images)
      PREFLIGHT_IMAGES=true
      shift
      ;;
    --rerun-passed)
      RERUN_PASSED=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_env() {
  local missing=0 var_name
  for var_name in "$@"; do
    if [[ -z "${!var_name:-}" ]]; then
      printf 'Error: required environment variable is missing: %s\n' "$var_name" >&2
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]]
}

normalize_json_bool() {
  local value var_name
  value=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  var_name=$2
  case "$value" in
    true|1|yes)
      printf 'true'
      ;;
    false|0|no)
      printf 'false'
      ;;
    *)
      printf 'Error: %s must be true or false.\n' "$var_name" >&2
      return 1
      ;;
  esac
}

require_file() {
  local file=$1
  if [[ ! -f "$file" ]]; then
    printf 'Error: required file not found: %s\n' "$file" >&2
    exit 1
  fi
}

on_error() {
  local line=$1
  trap - ERR
  if [[ -n "${TARGET_OBSERVER_PID:-}" ]]; then
    target_observer_stop "$TARGET_OBSERVER_PID" "" || true
  fi
  if [[ "$ERROR_RECORDED" == "true" ]]; then
    return
  fi
  ERROR_RECORDED=true
  if [[ "$DRY_RUN" != "true" && -n "$CURRENT_STATE_FILE" && -f "$CURRENT_STATE_FILE" ]]; then
    record_result "$CURRENT_STATE_FILE" fail "row execution failed at line ${line}" || true
  fi
}

trap 'on_error "$LINENO"' ERR

base64_no_wrap() {
  base64 | tr -d '\n'
}

json_string() {
  jq -Rn --arg value "$1" '$value'
}

sanitize_slug() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

os_key() {
  local os_type=$1 os_version=$2
  case "$(sanitize_slug "$os_type-$os_version")" in
    rocky-linux-*) printf 'rocky%s' "${os_version//./}" ;;
    red-hat-enterprise-linux-rhel-*) printf 'rhel%s' "${os_version//./}" ;;
    ubuntu-linux-*) printf 'ubuntu%s' "${os_version//./}" ;;
    debian-*) printf 'debian%s' "${os_version//./}" ;;
    *) printf '%s' "$(sanitize_slug "$os_type-$os_version")" ;;
  esac
}

row_id_for() {
  local ndb_version=$1 db_type=$2 os_type=$3 os_version=$4 db_version=$5 mongodb_edition=$6 mongodb_deployments=$7
  local ndb_key os_slug deploy_slug edition_slug
  ndb_key=${ndb_version//./}
  os_slug=$(os_key "$os_type" "$os_version")
  edition_slug=$(sanitize_slug "$mongodb_edition")
  deploy_slug=$(sanitize_slug "$mongodb_deployments")
  if [[ "$db_type" == "mongodb" ]]; then
    printf '%s-mg%s-%s-%s-%s' "$ndb_key" "${db_version//./}" "$os_slug" "$edition_slug" "$deploy_slug"
  else
    printf '%s-pg%s-%s' "$ndb_key" "$db_version" "$os_slug"
  fi
}

short_row_key() {
  local row_id=$1 checksum
  checksum=$(printf '%s' "$row_id" | cksum | cut -d' ' -f1)
  printf '%s-%s' "$(printf '%s' "$row_id" | cut -c1-24)" "$checksum"
}

expected_target_count() {
  jq -s -r '
    [
      .[][]
      | select(
          (.db_type == "pgsql" and .provisioning_role == "postgresql")
          or
          (.db_type == "mongodb" and .provisioning_role == "mongodb")
        )
    ] | length
  ' "$ROOT_DIR"/ndb/*/matrix.json
}

generate_targets() {
  mkdir -p "$(dirname "$TARGETS_FILE")"
  jq -s -r '
    def buildable:
      (.db_type == "pgsql" and .provisioning_role == "postgresql")
      or
      (.db_type == "mongodb" and .provisioning_role == "mongodb");
    def manifest_buildable:
      (.selection.db_type == "pgsql" and .selection.provisioning_role == "postgresql")
      or
      (.selection.db_type == "mongodb" and .selection.provisioning_role == "mongodb");
    def matrix_key:
      [.ndb_version,.db_type,.os_type,.os_version,.db_version] | @json;
    def manifest_key:
      [.selection.ndb_version,.selection.db_type,.selection.os_type,.selection.os_version,.selection.db_version] | @json;

    {
      matrix: [.[] | arrays[] | select(buildable)],
      manifests: [.[] | objects | select(.status == "success" and manifest_buildable)]
    }
    | (.manifests | group_by(manifest_key) | map(max_by(.finished_at // .started_at // ""))) as $latest
    | ($latest | map({key: manifest_key, value: .}) | from_entries) as $manifest_by_key
    | .matrix[]
    | . as $row
    | ($manifest_by_key[($row | matrix_key)] // empty) as $manifest
    | [
        $row.ndb_version,
        $row.db_type,
        $row.os_type,
        $row.os_version,
        $row.db_version,
        ($row.mongodb_edition // ""),
        (($row.deployment // []) | join(",")),
        $manifest.artifact.image_name,
        $manifest.artifact.image_uuid,
        ($manifest.finished_at // "")
      ]
    | map(tostring)
    | join("|")
  ' "$ROOT_DIR"/ndb/*/matrix.json "$ROOT_DIR"/manifests/*.json | sort > "$TARGETS_FILE"
}

api_url() {
  printf 'https://%s:8443/era/v0.9%s' "$NDB_SERVER_ADDRESS" "$1"
}

ndb_get() {
  curl --max-time "$NDB_API_TIMEOUT" -sSk -u "${NDB_SERVER_USER}:${NDB_SERVER_PASSWORD}" "$(api_url "$1")"
}

ndb_post_file() {
  curl --max-time "$NDB_API_TIMEOUT" -sSk -u "${NDB_SERVER_USER}:${NDB_SERVER_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST "$(api_url "$1")" \
    -d @"$2"
}

extract_task_uuid() {
  jq -r '.status.execution_context.task_uuid // .task_uuid // ""'
}

wait_prism_response_task() {
  local response=$1 action=$2 task_uuid
  task_uuid=$(extract_task_uuid <<<"$response")
  if [[ -z "$task_uuid" ]]; then
    printf 'Error: Prism %s response did not include a task UUID.\n' "$action" >&2
    return 1
  fi
  prism_wait_task "$task_uuid" >/dev/null
}

delete_disposable_vm() {
  local vm_uuid=$1 reason=$2
  local response task_uuid

  if [[ -z "$vm_uuid" ]]; then
    return 0
  fi

  printf 'Deleting disposable VM %s (%s)...\n' "$vm_uuid" "$reason" >&2
  response=$(prism_delete_vm "$vm_uuid") || return 1
  task_uuid=$(extract_task_uuid <<<"$response")
  if [[ -n "$task_uuid" ]]; then
    prism_wait_task "$task_uuid" >/dev/null
  fi
}

wait_operation() {
  local operation_id=$1 label=$2 output_file=$3
  local i json status pct step msg progress_key last_progress_key stall_count
  last_progress_key=""
  stall_count=0
  for i in $(seq 1 "$OPERATION_MAX_POLLS"); do
    json=$(ndb_get "/operations/${operation_id}")
    status=$(jq -r '.status // empty' <<<"$json")
    pct=$(jq -r '.percentageComplete // empty' <<<"$json")
    step=$(jq -r '[.steps[]? | select(.status == "1") | .name][0] // empty' <<<"$json")
    msg=$(jq -r '.message // empty' <<<"$json")
    printf '%s poll=%s status=%s pct=%s step=%s msg=%s\n' "$label" "$i" "$status" "$pct" "$step" "$msg"
    progress_key="${status}|${pct}|${step}|${msg}"
    if [[ "$progress_key" == "$last_progress_key" ]]; then
      stall_count=$((stall_count + 1))
    else
      stall_count=0
      last_progress_key="$progress_key"
    fi
    if [[ "$status" == "5" || "$status" == "2" || "$status" == "4" || "$status" == "6" ]]; then
      printf '%s\n' "$json" > "$output_file"
      [[ "$status" == "5" ]]
      return
    fi
    if [[ "$status" == "1" && "$OPERATION_STALL_POLLS" -gt 0 && "$stall_count" -ge "$OPERATION_STALL_POLLS" ]]; then
      printf '%s\n' "$json" > "$output_file"
      printf 'Error: %s made no observable progress for %s polls.\n' "$label" "$stall_count" >&2
      return 1
    fi
    sleep "$OPERATION_POLL_SECONDS"
  done
  printf '%s\n' "$json" > "$output_file"
  return 1
}

lookup_software_profile() {
  local profile_name=$1 engine_type=$2
  ndb_get "/profiles?type=Software&engine=${engine_type}" \
    | jq -c --arg profile_name "$profile_name" '
        if type == "array" then
          [.[] | select(.name == $profile_name)][0] // empty
        else
          empty
        end
      '
}

lookup_network_profile_id() {
  local engine_type=$1
  ndb_get "/profiles?type=Network&engine=${engine_type}" \
    | jq -r '
        if type == "array" then
          [.[] | select(.status == "READY")][0].id // ""
        else
          ""
        end
      '
}

network_profile_id_for() {
  local db_type=$1 profile_id
  if [[ "$db_type" == "pgsql" ]]; then
    printf '%s\n' "$NDB_POSTGRES_NETWORK_PROFILE_ID"
    return 0
  fi

  if [[ -n "$NDB_MONGODB_NETWORK_PROFILE_ID" ]]; then
    printf '%s\n' "$NDB_MONGODB_NETWORK_PROFILE_ID"
    return 0
  fi

  profile_id=$(lookup_network_profile_id "mongodb_database")
  if [[ -n "$profile_id" ]]; then
    printf '%s\n' "$profile_id"
    return 0
  fi

  printf 'Error: no READY MongoDB NDB network profile found. Create one or set NDB_E2E_MONGODB_NETWORK_PROFILE_ID.\n' >&2
  return 1
}

ssh_options() {
  printf '%s\n' \
    -i "$PRIVATE_KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o IdentitiesOnly=yes \
    -o IdentityAgent=none \
    -o BatchMode=yes \
    -o ConnectTimeout=5
}

ssh_as() {
  local user=$1 ip=$2
  shift 2
  ssh $(ssh_options) "${user}@${ip}" "$@"
}

wait_ssh() {
  local user=$1 ip=$2
  local i
  for i in $(seq 1 "$SSH_MAX_POLLS"); do
    if ssh_as "$user" "$ip" true >/dev/null 2>&1; then
      return 0
    fi
    sleep 10
  done
  ssh_as "$user" "$ip" true >/dev/null
}

guest_boot_ready_probe() {
  cat <<'EOF'
test -S /run/dbus/system_bus_socket || exit 1
state=$(systemctl is-system-running 2>/dev/null || true)
case "$state" in
  running|degraded) ;;
  *) exit 1 ;;
esac
if command -v cloud-init >/dev/null 2>&1; then
  cloud_state=$(cloud-init status 2>/dev/null || true)
  case "$cloud_state" in
    *"status: running"*) exit 1 ;;
  esac
fi
EOF
}

wait_guest_boot_ready() {
  local user=$1 ip=$2
  local i

  printf 'Waiting for systemd/D-Bus readiness on %s...\n' "$ip"
  for i in $(seq 1 "$GUEST_READY_MAX_POLLS"); do
    if ssh_as "$user" "$ip" "$(guest_boot_ready_probe)" >/dev/null 2>&1; then
      return 0
    fi
    sleep 10
  done

  ssh_as "$user" "$ip" "systemctl is-system-running || true; ls -l /run/dbus/system_bus_socket || true; cloud-init status || true" >&2 || true
  ssh_as "$user" "$ip" "$(guest_boot_ready_probe)" >/dev/null
}

target_observer_operation_ips() {
  local operation_file=$1 source_ip=${2:-}
  jq -r '.. | strings' "$operation_file" 2>/dev/null \
    | sed -nE 's/.*(^|[^0-9])(([0-9]{1,3}\.){3}[0-9]{1,3})([^0-9]|$).*/\2/p' \
    | awk -v source_ip="$source_ip" -v ndb_ip="${NDB_SERVER_ADDRESS:-}" '
        $0 != "" && $0 != source_ip && $0 != ndb_ip && !seen[$0]++
      '
}

target_observer_prism_ips() {
  local state_file=$1 observer_dir=$2 iteration=$3 stamp=$4
  local vm_name vm_uuid vm_json vm_file

  vm_name=$(jq -r '.provisioned_vm_name // ""' "$state_file" 2>/dev/null)
  [[ -n "$vm_name" ]] || return 0

  vm_uuid=$(prism_vm_uuid_by_name "$vm_name" 2>"$observer_dir/last-prism-vm-lookup.err" | head -n 1)
  [[ -n "$vm_uuid" ]] || return 0

  vm_json=$(prism_vm_json "$vm_uuid" 2>"$observer_dir/last-prism-vm.err") || return 0
  vm_file="$observer_dir/prism-vms/${iteration}-${stamp}.json"
  printf '%s\n' "$vm_json" > "$vm_file"
  chmod 600 "$vm_file" 2>/dev/null || true

  jq --arg observed_target_vm_uuid "$vm_uuid" \
    '. + {observed_target_vm_uuid: $observed_target_vm_uuid}' \
    "$state_file" > "${state_file}.tmp" 2>/dev/null && mv "${state_file}.tmp" "$state_file" && chmod 600 "$state_file"

  jq -r '.status.resources.nic_list[]?.ip_endpoint_list[]?.ip // empty' <<<"$vm_json" 2>/dev/null
}

target_observer_snapshot() {
  local ip=$1 observer_dir=$2 iteration=$3 stamp=$4
  local target_dir output_file error_file rc

  target_dir="$observer_dir/targets/$ip"
  mkdir -p "$target_dir"
  chmod 700 "$target_dir"
  output_file="$target_dir/${iteration}-${stamp}.txt"
  error_file="$target_dir/${iteration}-${stamp}.err"

  if ssh_as era "$ip" "bash -s" >"$output_file" 2>"$error_file" <<'EOF'
set +e

sanitize_stream() {
  sed -E \
    -e 's/(ansible_(ssh|sudo)_pass=)[^[:space:]]+/\1[REDACTED]/g' \
    -e 's/(register_host\.sh.* admin )[^[:space:]]+/\1[REDACTED]/g' \
    -e 's/(--vault-password-file )[^\047"[:space:]]+/\1[REDACTED_PATH]/g' \
    -e 's/((DB_PASSWORD|DB_PASS|db_password|db_pass)[[:space:]]*=?[[:space:]]*)[^[:space:]]+/\1[REDACTED]/gI' \
    -e 's/(("?[A-Za-z0-9_-]*(password|passwd|secret|token|credential|api[_-]?key)[A-Za-z0-9_-]*"?[[:space:]]*[:=][[:space:]]*)"?)[^"[:space:],;}]+(")?/\1[REDACTED]\4/gI' \
    -e 's/((--?[A-Za-z0-9_-]*(password|passwd|secret|token|credential|api[_-]?key)[A-Za-z0-9_-]*|-p)[ =])[^[:space:]]+/\1[REDACTED]/gI' \
    -e 's/([Pp]assword|[Pp]asswd|[Ss]ecret|[Tt]oken|[Cc]redential|[Aa][Pp][Ii][_-]?[Kk]ey)([^[:space:]]*[[:space:]]*[:=][[:space:]]*)[^[:space:],;]+/\1\2[REDACTED]/g' \
    -e 's/(PGPASSWORD=)[^[:space:]]+/\1[REDACTED]/g'
}

section() {
  printf '\n### %s\n' "$1"
}

section "identity"
date -u '+observer_utc=%Y-%m-%dT%H:%M:%SZ'
hostnamectl 2>/dev/null | sanitize_stream || hostname
whoami
id
uptime

section "network"
ip -brief addr 2>&1 | sanitize_stream || ip addr 2>&1 | sanitize_stream
ip route 2>&1 | sanitize_stream

section "listeners"
sudo -n ss -ltnp 2>&1 | sanitize_stream || ss -ltn 2>&1 | sanitize_stream

section "processes"
ps -eo pid,ppid,stat,user,comm,args 2>&1 \
  | grep -E 'era|postgres|python|java|driver|register|ndb|patroni|etcd|haproxy|keepalived' \
  | grep -v grep \
  | sanitize_stream || true

section "systemd-failed"
systemctl --no-pager --failed 2>&1 | sanitize_stream || true

section "systemd-target-units"
sudo -n systemctl --no-pager status era_postgres.service postgresql postgresql-16 ndb-ssh-reset-gate.service ndb-password-reset.service ssh.service sshd.service 2>&1 \
  | sanitize_stream || true

section "mounts"
findmnt 2>&1 | sanitize_stream || true

section "era-base-files"
sudo -n find /opt/era_base -maxdepth 4 -type f -printf '%TY-%Tm-%TdT%TH:%TM:%TS %s %p\n' 2>&1 \
  | sort \
  | tail -300 \
  | sanitize_stream || true

section "era-tempdir-files"
sudo -n find /opt/era_base/tempdir -maxdepth 5 -type f -printf '%TY-%Tm-%TdT%TH:%TM:%TS %s %p\n' 2>&1 \
  | sort \
  | tail -300 \
  | sanitize_stream || true

section "candidate-log-files"
candidate_logs=$(mktemp)
sudo -n find /opt/era_base /tmp -maxdepth 8 -type f \( -name '*.log' -o -name '*.out' -o -name '*.err' \) -print 2>/dev/null \
  | grep -v '/opt/era_base/logs/monitoring/' \
  | sort \
  | tail -80 > "$candidate_logs"
while IFS= read -r log_file; do
  [[ -f "$log_file" ]] || continue
  sudo -n stat -c '%y %s %n' "$log_file" 2>&1 | sanitize_stream || true
done < "$candidate_logs"

while IFS= read -r log_file; do
  [[ -f "$log_file" ]] || continue
  section "tail $log_file"
  sudo -n tail -n 160 "$log_file" 2>&1 | sanitize_stream || true
done < "$candidate_logs"
rm -f "$candidate_logs"

section "journal"
(sudo -n journalctl --no-pager --since '-20 min' -n 500 -u era_postgres.service -u postgresql.service -u postgresql@16-main.service -u ssh.service -u sshd.service -u ndb-ssh-reset-gate.service -u ndb-password-reset.service 2>&1 \
  || journalctl --no-pager --since '-20 min' -n 500 -u era_postgres.service -u postgresql.service -u postgresql@16-main.service -u ssh.service -u sshd.service -u ndb-ssh-reset-gate.service -u ndb-password-reset.service 2>&1) \
  | sanitize_stream || true
EOF
  then
    rc=0
  else
    rc=$?
  fi
  chmod 600 "$output_file" "$error_file" 2>/dev/null || true
  if [[ "$rc" -eq 0 ]]; then
    printf '%s observer ssh snapshot succeeded for %s\n' "$stamp" "$ip" >> "$observer_dir/observer.log"
  else
    printf '%s observer ssh snapshot failed for %s rc=%s\n' "$stamp" "$ip" "$rc" >> "$observer_dir/observer.log"
  fi
  return 0
}

target_observer_loop() {
  set +e
  trap - ERR
  trap 'exit 0' TERM INT

  local state_file=$1 operation_id=$2 observer_dir=$3
  local start_epoch deadline iteration stamp json op_file status source_ip ip ip_file

  start_epoch=$(date +%s)
  deadline=$((start_epoch + TARGET_OBSERVER_MAX_SECONDS))
  iteration=0
  source_ip=$(jq -r '.source_vm_ip // ""' "$state_file" 2>/dev/null)

  while [[ "$(date +%s)" -lt "$deadline" ]]; do
    iteration=$((iteration + 1))
    stamp=$(date -u +%Y%m%dT%H%M%SZ)
    op_file="$observer_dir/operations/${iteration}-${stamp}.json"

    json=$(ndb_get "/operations/${operation_id}" 2>"$observer_dir/last-ndb-poll.err")
    if [[ -n "$json" ]] && jq empty <<<"$json" >/dev/null 2>&1; then
      printf '%s\n' "$json" > "$op_file"
      chmod 600 "$op_file" 2>/dev/null || true
      status=$(jq -r '.status // empty' <<<"$json")
      ip_file=$(mktemp "$observer_dir/target-ips.XXXXXX")
      target_observer_operation_ips "$op_file" "$source_ip" >> "$ip_file" 2>/dev/null || true
      target_observer_prism_ips "$state_file" "$observer_dir" "$iteration" "$stamp" >> "$ip_file" 2>/dev/null || true
      while IFS= read -r ip; do
        [[ -n "$ip" ]] || continue
        if ! grep -qx "$ip" "$observer_dir/target-ips.txt" 2>/dev/null; then
          printf '%s\n' "$ip" >> "$observer_dir/target-ips.txt"
          jq --arg observed_target_ip "$ip" \
            '. + {observed_target_ips: (((.observed_target_ips // []) + [$observed_target_ip]) | unique)}' \
            "$state_file" > "${state_file}.tmp" 2>/dev/null && mv "${state_file}.tmp" "$state_file" && chmod 600 "$state_file"
        fi
        target_observer_snapshot "$ip" "$observer_dir" "$iteration" "$stamp"
      done < <(sort -u "$ip_file")
      rm -f "$ip_file"
      case "$status" in
        2|4|5|6) break ;;
      esac
    else
      printf '%s observer NDB poll failed or returned non-JSON for operation %s\n' "$stamp" "$operation_id" >> "$observer_dir/observer.log"
    fi

    sleep "$TARGET_OBSERVER_INTERVAL_SECONDS" &
    wait $!
  done
}

target_observer_start() {
  local state_file=$1 operation_id=$2 observer_dir=$3

  if [[ "$TARGET_OBSERVER" != "true" ]]; then
    return 0
  fi

  mkdir -p "$observer_dir/operations" "$observer_dir/prism-vms" "$observer_dir/targets"
  chmod 700 "$observer_dir" "$observer_dir/operations" "$observer_dir/prism-vms" "$observer_dir/targets"
  jq -n \
    --arg operation_id "$operation_id" \
    --arg state_file "$state_file" \
    --arg started_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson interval_seconds "$TARGET_OBSERVER_INTERVAL_SECONDS" \
    --argjson max_seconds "$TARGET_OBSERVER_MAX_SECONDS" \
    '{
      operation_id: $operation_id,
      state_file: $state_file,
      started_at: $started_at,
      interval_seconds: $interval_seconds,
      max_seconds: $max_seconds
    }' > "$observer_dir/metadata.json"
  chmod 600 "$observer_dir/metadata.json"

  jq --arg target_observer_dir "$observer_dir" \
    '. + {target_observer_dir: $target_observer_dir}' "$state_file" > "${state_file}.tmp"
  mv "${state_file}.tmp" "$state_file"
  chmod 600 "$state_file"

  printf 'Target observer enabled: %s\n' "$observer_dir"
  target_observer_loop "$state_file" "$operation_id" "$observer_dir" &
  TARGET_OBSERVER_PID=$!
}

target_observer_stop() {
  local pid=${1:-} observer_dir=${2:-}

  if [[ -n "$pid" ]]; then
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    wait "$pid" 2>/dev/null || true
  fi
  if [[ -n "$observer_dir" && -d "$observer_dir" ]]; then
    printf '%s observer stopped\n' "$(date -u +%Y%m%dT%H%M%SZ)" >> "$observer_dir/observer.log"
    chmod 600 "$observer_dir/observer.log" 2>/dev/null || true
  fi
  TARGET_OBSERVER_PID=""
}

resolve_image_uuid() {
  local image_name=$1 image_uuid=$2 resolved_uuid
  if prism_image_uuid_exists "$image_uuid"; then
    printf '%s\n' "$image_uuid"
    return 0
  fi

  resolved_uuid=$(prism_image_uuid_by_name "$image_name")
  if [[ -n "$resolved_uuid" ]]; then
    printf 'Warning: manifest image UUID %s was not found; using current Prism UUID %s for image %s.\n' "$image_uuid" "$resolved_uuid" "$image_name" >&2
    printf '%s\n' "$resolved_uuid"
    return 0
  fi

  printf 'Error: image is not present in Prism by UUID or name: %s (%s)\n' "$image_name" "$image_uuid" >&2
  return 1
}

create_source_vm() {
  local state_file=$1 row_id=$2 image_name=$3 image_uuid=$4 db_version=$5 db_type=$6
  local cluster_uuid subnet_uuid timestamp short_key vm_name ssh_public_key user_data_b64 create_payload create_response vm_uuid power_response vm_ip attempt source_ready

  image_uuid=$(resolve_image_uuid "$image_name" "$image_uuid")
  cluster_uuid=$(prism_cluster_uuid_by_name "$PKR_VAR_cluster_name")
  subnet_uuid=$(prism_subnet_uuid_by_name "$PKR_VAR_subnet_name")
  if [[ -z "$cluster_uuid" || -z "$subnet_uuid" ]]; then
    printf 'Error: could not resolve Prism cluster/subnet UUID.\n' >&2
    return 1
  fi

  short_key=$(short_row_key "$row_id")
  ssh_public_key=$(tr -d '\n' < "$PUBLIC_KEY_PATH")
  user_data_b64=$(sed "s|\${ssh_public_key}|${ssh_public_key}|g" "$USER_DATA_TEMPLATE" | base64_no_wrap)

  for attempt in $(seq 1 "$SOURCE_VM_MAX_ATTEMPTS"); do
    timestamp=$(date +%Y%m%d%H%M%S)
    vm_name="ndb-e2e-src-${short_key}-${timestamp}-a${attempt}"
    vm_uuid=""
    vm_ip=""
    source_ready=false

    create_payload=$(jq -n \
      --arg vm_name "$vm_name" \
      --arg cluster_uuid "$cluster_uuid" \
      --arg subnet_uuid "$subnet_uuid" \
      --arg image_uuid "$image_uuid" \
      --arg user_data "$user_data_b64" \
      --arg db_type "$db_type" \
      --argjson postgres_software_disk_size_mib "$((NDB_POSTGRES_SOFTWARE_DISK_SIZE_GB * 1024))" \
      '{
        spec: {
          name: $vm_name,
          cluster_reference: {kind: "cluster", uuid: $cluster_uuid},
          resources: {
            num_sockets: 2,
            num_vcpus_per_socket: 1,
            memory_size_mib: 4096,
            power_state: "OFF",
            boot_config: {
              boot_type: "UEFI",
              boot_device_order_list: ["DISK", "CDROM", "NETWORK"]
            },
            disk_list: ([
              {
                data_source_reference: {kind: "image", uuid: $image_uuid},
                device_properties: {
                  device_type: "DISK",
                  disk_address: {adapter_type: "SCSI", device_index: 0}
                }
              }
            ] + (
              if $db_type == "pgsql" then [
                {
                  disk_size_mib: $postgres_software_disk_size_mib,
                  device_properties: {
                    device_type: "DISK",
                    disk_address: {adapter_type: "SCSI", device_index: 1}
                  }
                }
              ] else [] end
            )),
            nic_list: [
              {
                subnet_reference: {kind: "subnet", uuid: $subnet_uuid},
                is_connected: true
              }
            ],
            serial_port_list: [{index: 0, is_connected: true}],
            guest_customization: {cloud_init: {user_data: $user_data}}
          }
        },
        metadata: {kind: "vm"}
      }')

    printf 'Creating source VM %s from image %s (attempt %s/%s)...\n' "$vm_name" "$image_name" "$attempt" "$SOURCE_VM_MAX_ATTEMPTS"
    create_response=$(prism_curl POST /api/nutanix/v3/vms "$create_payload")
    vm_uuid=$(jq -r '.metadata.uuid // ""' <<<"$create_response")
    if [[ -z "$vm_uuid" ]]; then
      printf 'Error: Prism create response did not include VM UUID.\n' >&2
      return 1
    fi
    wait_prism_response_task "$create_response" "create VM"

    printf 'Powering on source VM %s...\n' "$vm_uuid"
    power_response=$(prism_power_on_vm "$vm_uuid")
    wait_prism_response_task "$power_response" "power on VM"

    printf 'Waiting for source VM IP...\n'
    for _ in $(seq 1 90); do
      vm_ip=$(prism_vm_ip "$vm_uuid")
      [[ -n "$vm_ip" ]] && break
      sleep 10
    done

    jq -n \
      --arg row_id "$row_id" \
      --arg image_name "$image_name" \
      --arg image_uuid "$image_uuid" \
      --arg source_vm_name "$vm_name" \
      --arg source_vm_uuid "$vm_uuid" \
      --arg source_vm_ip "$vm_ip" \
      --arg db_version "$db_version" \
      --arg source_vm_attempt "$attempt" \
      '{
        row_id: $row_id,
        image_name: $image_name,
        image_uuid: $image_uuid,
        source_vm_name: $source_vm_name,
        source_vm_uuid: $source_vm_uuid,
        source_vm_ip: $source_vm_ip,
        source_vm_attempt: ($source_vm_attempt | tonumber),
        db_version: $db_version
      }' > "$state_file"

    if [[ -n "$vm_ip" ]]; then
      printf 'Waiting for SSH on %s...\n' "$vm_ip"
      if wait_ssh packer "$vm_ip" && wait_guest_boot_ready packer "$vm_ip"; then
        source_ready=true
      fi
    else
      printf 'Source VM %s did not report an IP before timeout.\n' "$vm_uuid" >&2
    fi

    if [[ "$source_ready" == "true" ]]; then
      return 0
    fi

    if (( attempt < SOURCE_VM_MAX_ATTEMPTS )); then
      printf 'Source VM attempt %s/%s did not become SSH-ready; retrying with a fresh disposable VM.\n' "$attempt" "$SOURCE_VM_MAX_ATTEMPTS" >&2
      delete_disposable_vm "$vm_uuid" "source VM readiness retry" || true
      sleep 10
    fi
  done

  printf 'Error: source VM did not become SSH-ready after %s attempt(s).\n' "$SOURCE_VM_MAX_ATTEMPTS" >&2
  return 1
}

prepare_common_source_vm() {
  local state_file=$1
  local vm_ip era_password
  vm_ip=$(jq -r '.source_vm_ip' "$state_file")
  era_password=$(openssl rand -hex 18)
  printf 'Preparing source VM OS access for NDB registration...\n'
  printf 'era:%s\n' "$era_password" | ssh_as packer "$vm_ip" "sudo chpasswd"
  ssh_as packer "$vm_ip" "printf '%s\n' 'PasswordAuthentication yes' | sudo tee /etc/ssh/sshd_config.d/01-ndb-registration.conf >/dev/null && sudo systemctl reload sshd"
  jq --arg era_user "era" --arg era_password "$era_password" \
    '. + {era_user: $era_user, era_password: $era_password}' "$state_file" > "${state_file}.tmp"
  mv "${state_file}.tmp" "$state_file"
  chmod 600 "$state_file"
}

postgres_paths_json() {
  local os_type=$1 db_version=$2
  local postgres_software_home_base
  postgres_software_home_base=${NDB_POSTGRES_SOFTWARE_HOME_BASE%/}
  if [[ "$os_type" == "Debian" || "$os_type" == "Ubuntu Linux" ]]; then
    jq -n \
      --arg service "postgresql" \
      --arg psql "/usr/lib/postgresql/${db_version}/bin/psql" \
      --arg package_home "/usr/lib/postgresql/${db_version}" \
      --arg software_home "${postgres_software_home_base}/${db_version}" \
      --arg conf "/etc/postgresql/${db_version}/main/postgresql.conf" \
      --arg hba "/etc/postgresql/${db_version}/main/pg_hba.conf" \
      '{service:$service, psql:$psql, package_home:$package_home, software_home:$software_home, conf:$conf, hba:$hba}'
  else
    jq -n \
      --arg service "postgresql-${db_version}" \
      --arg psql "/usr/pgsql-${db_version}/bin/psql" \
      --arg package_home "/usr/pgsql-${db_version}" \
      --arg software_home "${postgres_software_home_base}/${db_version}" \
      --arg conf "/var/lib/pgsql/${db_version}/data/postgresql.conf" \
      --arg hba "/var/lib/pgsql/${db_version}/data/pg_hba.conf" \
      '{service:$service, psql:$psql, package_home:$package_home, software_home:$software_home, conf:$conf, hba:$hba}'
  fi
}

prepare_postgres_software_home() {
  local vm_ip=$1 package_home=$2 software_home=$3

  printf 'Preparing dedicated PostgreSQL software disk at %s...\n' "$software_home"
  ssh_as packer "$vm_ip" "sudo env NDB_PG_PACKAGE_HOME='$package_home' NDB_PG_SOFTWARE_HOME='$software_home' bash -s" <<'EOF'
set -euo pipefail

if [[ ! -d "${NDB_PG_PACKAGE_HOME}/bin" ]]; then
  printf 'PostgreSQL package home is missing or invalid: %s\n' "$NDB_PG_PACKAGE_HOME" >&2
  exit 1
fi

mkdir -p "$NDB_PG_SOFTWARE_HOME"

if ! mountpoint -q "$NDB_PG_SOFTWARE_HOME"; then
  software_disk=""
  while read -r disk _type; do
    [[ -n "$disk" ]] || continue
    # The saved image boot disk has filesystems; the temporary software disk is blank.
    if lsblk -nrpo FSTYPE "$disk" | grep -q '[^[:space:]]'; then
      continue
    fi
    if lsblk -nrpo MOUNTPOINT "$disk" | grep -q '/'; then
      continue
    fi
    software_disk="$disk"
    break
  done < <(lsblk -dnpo NAME,TYPE | awk '$2 == "disk" {print $1, $2}')

  if [[ -z "$software_disk" ]]; then
    printf 'No blank disk is available for PostgreSQL software home %s.\n' "$NDB_PG_SOFTWARE_HOME" >&2
    lsblk -fp >&2
    exit 1
  fi

  wipefs -a "$software_disk"
  mkfs.ext4 -F "$software_disk"
  software_disk_uuid=$(blkid -s UUID -o value "$software_disk")
  if ! grep -q "[[:space:]]${NDB_PG_SOFTWARE_HOME}[[:space:]]" /etc/fstab; then
    printf 'UUID=%s %s ext4 defaults,nofail 0 2\n' "$software_disk_uuid" "$NDB_PG_SOFTWARE_HOME" >> /etc/fstab
  fi
  mount "$NDB_PG_SOFTWARE_HOME"
fi

root_source=$(findmnt -rn -o SOURCE --target /)
software_source=$(findmnt -rn -o SOURCE --mountpoint "$NDB_PG_SOFTWARE_HOME" || true)
if [[ -z "$software_source" || "$software_source" == "$root_source" ]]; then
  printf 'PostgreSQL software home must be a dedicated non-root mountpoint: %s\n' "$NDB_PG_SOFTWARE_HOME" >&2
  findmnt "$NDB_PG_SOFTWARE_HOME" >&2 || true
  exit 1
fi

rm -rf "${NDB_PG_SOFTWARE_HOME:?}/"*
cp -a "${NDB_PG_PACKAGE_HOME}/." "$NDB_PG_SOFTWARE_HOME/"
chown -R root:root "$NDB_PG_SOFTWARE_HOME"
test -x "${NDB_PG_SOFTWARE_HOME}/bin/postgres"
test -x "${NDB_PG_SOFTWARE_HOME}/bin/psql"
"${NDB_PG_SOFTWARE_HOME}/bin/postgres" --version >/dev/null
mountpoint -q "$NDB_PG_SOFTWARE_HOME"
EOF
}

prepare_postgres_source_vm() {
  local state_file=$1 os_type=$2 db_version=$3
  local vm_ip db_password paths service psql package_home software_home conf hba
  vm_ip=$(jq -r '.source_vm_ip' "$state_file")
  db_password=$(openssl rand -hex 18)
  paths=$(postgres_paths_json "$os_type" "$db_version")
  service=$(jq -r '.service' <<<"$paths")
  psql=$(jq -r '.psql' <<<"$paths")
  package_home=$(jq -r '.package_home' <<<"$paths")
  software_home=$(jq -r '.software_home' <<<"$paths")
  conf=$(jq -r '.conf' <<<"$paths")
  hba=$(jq -r '.hba' <<<"$paths")

  printf 'Preparing PostgreSQL source VM for profile creation...\n'
  ssh_as packer "$vm_ip" "sudo systemctl start '$service' && sudo systemctl disable '$service'"
  ssh_as packer "$vm_ip" "sudo -u postgres '$psql' -c \"ALTER USER postgres WITH PASSWORD '${db_password}';\" >/dev/null"
  ssh_as packer "$vm_ip" "sudo sed -i \"s/^#\\?listen_addresses.*/listen_addresses = '*'/\" '$conf'"
  ssh_as packer "$vm_ip" "sudo grep -q '^host all all 0.0.0.0/0' '$hba' || printf '%s\n' 'host all all 0.0.0.0/0 scram-sha-256' | sudo tee -a '$hba' >/dev/null"
  ssh_as packer "$vm_ip" "if command -v firewall-cmd >/dev/null 2>&1; then sudo firewall-cmd --permanent --add-port=5432/tcp >/dev/null && sudo firewall-cmd --reload >/dev/null; fi"
  ssh_as packer "$vm_ip" "sudo systemctl restart '$service' && sudo systemctl disable '$service'"
  ssh_as packer "$vm_ip" "sudo -u postgres '$psql' -tAc 'select current_setting('\"'\"'server_version'\"'\"');' >/dev/null"
  prepare_postgres_software_home "$vm_ip" "$package_home" "$software_home"

  jq --arg db_user "postgres" \
    --arg db_password "$db_password" \
    --arg package_software_home "$package_home" \
    --arg software_home "$software_home" \
    --arg psql_path "${software_home}/bin/psql" \
    --arg listener_port "5432" \
    '. + {db_user:$db_user, db_password:$db_password, package_software_home:$package_software_home, software_home:$software_home, psql_path:$psql_path, listener_port:$listener_port}' \
    "$state_file" > "${state_file}.tmp"
  mv "${state_file}.tmp" "$state_file"
  chmod 600 "$state_file"
}

prepare_mongodb_source_vm() {
  local state_file=$1 db_version=$2
  local vm_ip db_password software_home db_os_user
  vm_ip=$(jq -r '.source_vm_ip' "$state_file")
  db_password=$(openssl rand -hex 18)
  software_home="$NDB_MONGODB_SOFTWARE_HOME"

  printf 'Preparing MongoDB source VM for profile creation...\n'
  ssh_as packer "$vm_ip" "test -x '${software_home}/bin/mongod'"
  ssh_as packer "$vm_ip" "test -x '${software_home}/bin/mongodump'"
  ssh_as packer "$vm_ip" "test -x '${software_home}/bin/mongorestore'"
  ssh_as packer "$vm_ip" "sudo systemctl start mongod && sudo systemctl disable mongod"
  ssh_as packer "$vm_ip" "if command -v firewall-cmd >/dev/null 2>&1; then sudo firewall-cmd --permanent --add-port=27017/tcp >/dev/null && sudo firewall-cmd --reload >/dev/null; fi"
  ssh_as packer "$vm_ip" "mongosh --quiet --eval 'db.adminCommand({ping:1}).ok' >/dev/null"
  ssh_as packer "$vm_ip" "mongod --version | grep -q 'db version v${db_version}\\.'"
  ssh_as packer "$vm_ip" "'${software_home}/bin/mongod' --version | grep -q 'db version v${db_version}\\.'"
  db_os_user=$(ssh_as packer "$vm_ip" "if getent passwd mongod >/dev/null 2>&1; then printf '%s\n' mongod; elif getent passwd mongodb >/dev/null 2>&1; then printf '%s\n' mongodb; else printf 'Error: neither mongod nor mongodb DB OS user exists.\\n' >&2; exit 1; fi")

  jq --arg db_user "admin" \
    --arg db_password "$db_password" \
    --arg db_os_user "$db_os_user" \
    --arg software_home "$software_home" \
    --arg listener_port "27017" \
    '. + {db_user:$db_user, db_password:$db_password, db_os_user:$db_os_user, software_home:$software_home, listener_port:$listener_port}' \
    "$state_file" > "${state_file}.tmp"
  mv "${state_file}.tmp" "$state_file"
  chmod 600 "$state_file"
}

prepare_debian_ndb_dm_serial_metadata() {
  local state_file=$1 os_type=$2
  local vm_ip

  if [[ "$os_type" != "Debian" && "$os_type" != "Ubuntu Linux" ]]; then
    return 0
  fi

  vm_ip=$(jq -r '.source_vm_ip' "$state_file")
  printf 'Preparing Debian/Ubuntu NDB Era-drive device-mapper metadata...\n'
  ssh_as packer "$vm_ip" "sudo bash -s" <<'EOF'
set -euo pipefail

if ! command -v udevadm >/dev/null 2>&1 || ! command -v dmsetup >/dev/null 2>&1; then
  exit 0
fi

rules_file=/etc/udev/rules.d/99-ndb-era-dm-serial.rules
tmp_rules=$(mktemp)
dm_devices=()

for dm_dev in /dev/dm-[0-9]*; do
  [[ -b "$dm_dev" ]] || continue
  kernel=$(basename "$dm_dev")
  [[ "$kernel" =~ ^dm-[0-9]+$ ]] || continue
  dm_vg=$(udevadm info --query=property --name="$dm_dev" | sed -n 's/^DM_VG_NAME=//p' | head -1)
  [[ "$dm_vg" == ntnx_era_agent_vg_* ]] || continue

  parent=$(dmsetup deps -o devname "$dm_dev" 2>/dev/null | sed -n 's/.*(\([^)]*\)).*/\1/p' | awk '{print $1}')
  [[ -n "$parent" && -b "/dev/$parent" ]] || continue
  serial=$(udevadm info --query=property --name="/dev/$parent" | sed -n 's/^ID_SERIAL=//p' | head -1)
  short_serial=$(udevadm info --query=property --name="/dev/$parent" | sed -n 's/^ID_SERIAL_SHORT=//p' | head -1)
  [[ -n "$serial" ]] || continue

  printf 'KERNEL=="%s", ENV{DM_VG_NAME}=="%s", ENV{ID_SERIAL}="%s", ENV{ID_SERIAL_SHORT}="%s"\n' \
    "$kernel" "$dm_vg" "$serial" "${short_serial:-$serial}" >> "$tmp_rules"

  # NDB 2.10 on Debian/Ubuntu can derive malformed /dev/dm-N.. paths while
  # mapping its own Era-drive LVM devices. Use symlinks so the driver's
  # fallback can resolve the path without creating extra block devices.
  alias="/dev/${kernel}.."
  if [[ -e "$alias" ]]; then
    if [[ -L "$alias" && "$(readlink "$alias")" == "$dm_dev" ]]; then
      :
    else
      rm -f "$alias"
      ln -s "$dm_dev" "$alias"
    fi
  else
    ln -s "$dm_dev" "$alias"
  fi

  dm_devices+=("$dm_dev")
done

if [[ -s "$tmp_rules" ]]; then
  install -m 0644 "$tmp_rules" "$rules_file"
  udevadm control --reload-rules
  for dm_dev in "${dm_devices[@]}"; do
    udevadm trigger --action=change --name-match="$dm_dev" || true
  done
  udevadm settle || true
fi

rm -f "$tmp_rules"
EOF
}

register_dbserver() {
  local state_file=$1 db_type=$2 payload_file=$3 response_file=$4 op_file=$5
  local dbserver_type software_arg_name dbserver_id register_operation_id
  if [[ "$db_type" == "pgsql" ]]; then
    dbserver_type="postgres_database"
    software_arg_name="postgres_software_home"
  else
    dbserver_type="mongodb_database"
    software_arg_name="software_home"
  fi

  jq -n --slurpfile state "$state_file" \
    --arg cluster_id "$NDB_CLUSTER_ID" \
    --arg dbserver_type "$dbserver_type" \
    --arg software_arg_name "$software_arg_name" \
    '{
      actionArguments: [
        {name: "listener_port", value: $state[0].listener_port},
        {name: $software_arg_name, value: $state[0].software_home},
        {name: "db_os_user", value: ($state[0].db_os_user // (if $dbserver_type == "postgres_database" then "postgres" else "mongod" end))}
      ],
      vmIp: $state[0].source_vm_ip,
      nxClusterUuid: $cluster_id,
      forcedInstall: true,
      workingDirectory: "/tmp",
      databaseType: $dbserver_type,
      username: $state[0].era_user,
      password: $state[0].era_password
    }' > "$payload_file"
  chmod 600 "$payload_file"

  printf 'Registering source DB server with NDB...\n'
  ndb_post_file /dbservers/register "$payload_file" > "$response_file"
  if ! jq -e 'type == "object" and ((.operationId // "") | length > 0)' "$response_file" >/dev/null; then
    printf 'Error: NDB DB server registration did not return an operationId.\n' >&2
    jq -r '
      if type == "object" then
        "NDB error " + ((.errorCode // .externalErrorCode // "unknown") | tostring) + ": " + (((.message // .Reason // "no message") | tostring) as $msg | if ($msg | length) > 1200 then ($msg[0:1200] + "...") else $msg end)
      else
        "Unexpected NDB response type: " + (type | tostring)
      end
    ' "$response_file" >&2
    return 1
  fi
  dbserver_id=$(jq -r '.entityId // empty' "$response_file")
  register_operation_id=$(jq -r '.operationId // empty' "$response_file")
  jq --arg dbserver_id "$dbserver_id" \
    --arg register_operation_id "$register_operation_id" \
    '. + {source_dbserver_id: $dbserver_id, register_operation_id: $register_operation_id}' "$state_file" > "${state_file}.tmp"
  mv "${state_file}.tmp" "$state_file"
  wait_operation "$register_operation_id" "register-op" "$op_file"
}

create_software_profile() {
  local state_file=$1 db_type=$2 os_type=$3 os_version=$4 profile_name=$5 payload_file=$6 response_file=$7 op_file=$8
  local engine_type notes
  if [[ "$db_type" == "pgsql" ]]; then
    engine_type="postgres_database"
    notes="PostgreSQL $(jq -r '.db_version' "$state_file")"
  else
    engine_type="mongodb_database"
    notes="MongoDB $(jq -r '.db_version' "$state_file")"
  fi

  jq -n --slurpfile state "$state_file" \
    --arg engine_type "$engine_type" \
    --arg profile_name "$profile_name" \
    --arg os_notes "${os_type} ${os_version}" \
    --arg db_notes "$notes" \
    '{
      engineType: $engine_type,
      type: "Software",
      dbVersion: $state[0].db_version,
      systemProfile: false,
      published: true,
      deprecated: false,
      properties: [
        {name: "SOURCE_DBSERVER_ID", value: $state[0].source_dbserver_id},
        {name: "SOFTWARE_PROFILE_TYPE", value: "NON_LPM"},
        {name: "BASE_PROFILE_VERSION_NAME", value: "v1"},
        {name: "BASE_PROFILE_VERSION_DESCRIPTION", value: ("Built from E2E validated image " + $state[0].image_name)},
        {name: "OS_NOTES", value: $os_notes},
        {name: "DB_SOFTWARE_NOTES", value: $db_notes}
      ],
      name: $profile_name,
      description: ("E2E validation profile from image " + $state[0].image_name)
    }' > "$payload_file"
  chmod 600 "$payload_file"

  printf 'Creating NDB software profile %s...\n' "$profile_name"
  ndb_post_file /profiles "$payload_file" > "$response_file"
  wait_operation "$(jq -r '.operationId' "$response_file")" "profile-op" "$op_file"

  local profile_json profile_id profile_version_id
  profile_json=$(lookup_software_profile "$profile_name" "$engine_type")
  profile_id=$(jq -r '.id // empty' <<<"$profile_json")
  profile_version_id=$(jq -r '.latestVersionId // empty' <<<"$profile_json")
  if [[ -z "$profile_id" || -z "$profile_version_id" ]]; then
    printf 'Error: software profile did not resolve to READY IDs.\n' >&2
    return 1
  fi
  jq --arg profile_id "$profile_id" \
    --arg software_profile_name "$profile_name" \
    --arg profile_version_id "$profile_version_id" \
    '. + {software_profile_name: $software_profile_name, software_profile_id: $profile_id, software_profile_version_id: $profile_version_id}' "$state_file" > "${state_file}.tmp"
  mv "${state_file}.tmp" "$state_file"
}

common_tm_json() {
  local db_name=$1
  jq -n --arg tm_name "${db_name}_TM" --arg sla_id "$NDB_SLA_ID" '{
    name: $tm_name,
    description: "NDB E2E validation time machine",
    slaId: $sla_id,
    schedule: {
      snapshotTimeOfDay: {hours: 1, minutes: 0, seconds: 0},
      continuousSchedule: {enabled: false, logBackupInterval: 30, snapshotsPerDay: 1},
      weeklySchedule: {enabled: false, dayOfWeek: "FRIDAY"},
      monthlySchedule: {enabled: false, dayOfMonth: "17"},
      quartelySchedule: {enabled: false, startMonth: "JANUARY", dayOfMonth: "17"},
      yearlySchedule: {enabled: false, dayOfMonth: 31, month: "DECEMBER"}
    },
    tags: [],
    autoTuneLogDrive: true
  }'
}

provision_database() {
  local state_file=$1 db_type=$2 db_name=$3 vm_name=$4 payload_file=$5 response_file=$6 op_file=$7
  local engine_type listener_port db_param_profile network_profile_id tm_json observer_dir wait_rc
  if [[ "$db_type" == "pgsql" ]]; then
    engine_type="postgres_database"
    listener_port="5432"
    db_param_profile="$NDB_POSTGRES_DB_PARAM_PROFILE_ID"
  else
    engine_type="mongodb_database"
    listener_port="27017"
    db_param_profile="$NDB_MONGODB_DB_PARAM_PROFILE_ID"
  fi
  network_profile_id=$(network_profile_id_for "$db_type")
  tm_json=$(common_tm_json "$db_name")

  jq -n --slurpfile state "$state_file" \
    --arg db_type "$db_type" \
    --arg engine_type "$engine_type" \
    --arg db_name "$db_name" \
    --arg vm_name "$vm_name" \
    --arg compute_profile_id "$NDB_COMPUTE_PROFILE_ID" \
    --arg network_profile_id "$network_profile_id" \
    --arg db_parameter_profile_id "$db_param_profile" \
    --arg nx_cluster_id "$NDB_CLUSTER_ID" \
    --arg listener_port "$listener_port" \
    --argjson delete_vm_on_failure "$DELETE_VM_ON_FAILURE" \
    --argjson time_machine "$tm_json" \
    --rawfile ssh_public_key "$PUBLIC_KEY_PATH" \
    '
    ({
      databaseType: $engine_type,
      name: $db_name,
      databaseDescription: "NDB E2E validation database",
      softwareProfileId: $state[0].software_profile_id,
      softwareProfileVersionId: $state[0].software_profile_version_id,
      computeProfileId: $compute_profile_id,
      networkProfileId: $network_profile_id,
      dbParameterProfileId: $db_parameter_profile_id,
      newDbServerTimeZone: "UTC",
      actionArguments: (
        if $db_type == "pgsql" then ([
          {name: "application_type", value: $engine_type},
          {name: "listener_port", value: $listener_port},
          {name: "database_size", value: "200"},
          {name: "auto_tune_staging_drive", value: "true"},
          {name: "auto_tune_log_drive", value: "true"},
          {name: "cluster_database", value: false},
          {name: "deploy_haproxy", value: "false"},
          {name: "enable_synchronous_mode", value: "false"},
          {name: "backup_policy", value: "primary_only"},
          {name: "dbserver_description", value: "NDB E2E validation DB server"},
          {name: "database_names", value: $db_name},
          {name: "db_password", value: $state[0].db_password},
          {name: "db_user", value: $state[0].db_user},
          {name: "delete_vm_on_failure", value: $delete_vm_on_failure}
        ]) else ([
          {name: "application_type", value: $engine_type},
          {name: "listener_port", value: $listener_port},
          {name: "database_size", value: "200"},
          {name: "journal_size", value: "100"},
          {name: "log_size", value: "100"},
          {name: "cluster_id", value: $nx_cluster_id},
          {name: "cluster_database", value: false},
          {name: "nodes", value: "1"},
          {name: "restart_mongod", value: "true"},
          {name: "backup_policy", value: "primary_only"},
          {name: "dbserver_description", value: "NDB E2E validation DB server"},
          {name: "database_names", value: $db_name},
          {name: "db_password", value: $state[0].db_password},
          {name: "db_user", value: $state[0].db_user},
          {name: "working_dir", value: "/tmp"},
          {name: "delete_vm_on_failure", value: $delete_vm_on_failure}
        ]) end
      ),
      createDbserver: true,
      nodeCount: 1,
      nxClusterId: $nx_cluster_id,
      sshPublicKey: ($ssh_public_key | gsub("\\n$"; "")),
      clustered: false,
      nodes: [{properties: [], vmName: $vm_name}],
      timeMachineInfo: $time_machine
    })' > "$payload_file"
  chmod 600 "$payload_file"

  printf 'Provisioning %s database %s...\n' "$engine_type" "$db_name"
  ndb_post_file /databases/provision "$payload_file" > "$response_file"
  local provision_operation_id
  provision_operation_id=$(jq -r '.operationId // empty' "$response_file")
  if [[ -z "$provision_operation_id" ]]; then
    printf 'Error: NDB provision response did not include operationId.\n' >&2
    jq '.' "$response_file" >&2
    return 1
  fi
  jq --arg provision_operation_id "$provision_operation_id" \
    --arg database_id "$(jq -r '.entityId // empty' "$response_file")" \
    --arg database_name "$db_name" \
    --arg provisioned_vm_name "$vm_name" \
    '. + {provision_operation_id: $provision_operation_id, database_id: $database_id, database_name: $database_name, provisioned_vm_name: $provisioned_vm_name}' "$state_file" > "${state_file}.tmp"
  mv "${state_file}.tmp" "$state_file"
  observer_dir="$(dirname "$state_file")/target-observer"
  target_observer_start "$state_file" "$provision_operation_id" "$observer_dir"
  wait_rc=0
  wait_operation "$provision_operation_id" "provision-op" "$op_file" || wait_rc=$?
  target_observer_stop "$TARGET_OBSERVER_PID" "$observer_dir"
  if [[ "$wait_rc" -ne 0 ]]; then
    return "$wait_rc"
  fi

  jq --arg provision_operation_id "$(jq -r '.operationId' "$response_file")" \
    --arg database_id "$(jq -r '.entityId // empty' "$response_file")" \
    --arg database_name "$db_name" \
    --arg provisioned_vm_name "$vm_name" \
    '. + {provision_operation_id: $provision_operation_id, database_id: $database_id, database_name: $database_name, provisioned_vm_name: $provisioned_vm_name}' "$state_file" > "${state_file}.tmp"
  mv "${state_file}.tmp" "$state_file"
}

extract_provisioned_ip() {
  local op_file=$1
  jq -r '.. | objects | .name? // empty' "$op_file" \
    | sed -nE 's/.*\[ ?([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ?\].*/\1/p' \
    | tail -n 1
}

validate_guest_database() {
  local state_file=$1 db_type=$2 provision_ip=$3
  local db_name db_user db_password psql_path validation
  db_name=$(jq -r '.database_name' "$state_file")
  db_user=$(jq -r '.db_user' "$state_file")
  db_password=$(jq -r '.db_password' "$state_file")

  wait_ssh era "$provision_ip"
  if [[ "$db_type" == "pgsql" ]]; then
    psql_path=$(jq -r '.psql_path' "$state_file")
    validation=$(printf '%s\n' "$db_password" | ssh_as era "$provision_ip" "read -r PGPASSWORD; export PGPASSWORD; '$psql_path' -h 127.0.0.1 -U '$db_user' -d '$db_name' -tAc \"select current_database() || '|' || current_setting('server_version');\"")
    validation=$(printf '%s' "$validation" | tr '\n' '|' | sed 's/|$//')
  else
    validation=$(printf '%s\n' "$db_password" | ssh_as era "$provision_ip" "read -r DB_PASSWORD; mongosh --quiet --host 127.0.0.1 --port 27017 -u '$db_user' -p \"\$DB_PASSWORD\" --authenticationDatabase admin --eval 'db.adminCommand({ping:1}).ok + \"|\" + db.version()'")
  fi

  jq --arg provisioned_vm_ip "$provision_ip" \
    --arg validation "$validation" \
    '. + {provisioned_vm_ip: $provisioned_vm_ip, guest_validation: $validation}' "$state_file" > "${state_file}.tmp"
  mv "${state_file}.tmp" "$state_file"
  printf 'Guest validation: %s\n' "$validation"
}

record_result() {
  local state_file=$1 status=$2 error_message=${3:-}
  jq -c --arg status "$status" --arg error_message "$error_message" '{
    row_id,
    status: $status,
    error_message: $error_message,
    image_name,
    image_uuid,
    source_vm_name,
    source_vm_uuid,
    source_vm_ip,
    register_operation_id,
    source_dbserver_id,
    software_profile_name,
    software_profile_id,
    software_profile_version_id,
    provision_operation_id,
    database_id,
    database_name,
    provisioned_vm_name,
    provisioned_vm_ip,
    guest_validation
  }' "$state_file" >> "$EVIDENCE_FILE"
}

row_already_passed() {
  local row_id=$1
  [[ -f "$EVIDENCE_FILE" ]] || return 1
  jq -e --arg row_id "$row_id" 'select(.row_id == $row_id and .status == "pass")' "$EVIDENCE_FILE" >/dev/null 2>&1
}

preflight_target_images() {
  local images_file ndb_version db_type os_type os_version db_version mongodb_edition mongodb_deployments image_name image_uuid finished_at
  local row_id selected=0 missing=0
  images_file=$(mktemp -t ndb-e2e-images.XXXXXX)
  prism_list_resource images image 5000 > "$images_file"

  while IFS='|' read -r ndb_version db_type os_type os_version db_version mongodb_edition mongodb_deployments image_name image_uuid finished_at; do
    [[ -n "$DB_TYPE_FILTER" && "$db_type" != "$DB_TYPE_FILTER" ]] && continue
    row_id=$(row_id_for "$ndb_version" "$db_type" "$os_type" "$os_version" "$db_version" "$mongodb_edition" "$mongodb_deployments")
    [[ -n "$ROW_FILTER" && "$row_id" != "$ROW_FILTER" ]] && continue
    if [[ "$RERUN_PASSED" != "true" ]] && row_already_passed "$row_id"; then
      continue
    fi
    selected=$((selected + 1))
    if jq -e --arg name "$image_name" --arg uuid "$image_uuid" '
      .entities[]?
      | select((.metadata.uuid // "") == $uuid or (.spec.name // .status.name // "") == $name)
    ' "$images_file" >/dev/null; then
      printf 'Image present: %s\n' "$row_id"
    else
      printf 'Error: image missing in Prism for %s: %s (%s)\n' "$row_id" "$image_name" "$image_uuid" >&2
      missing=$((missing + 1))
    fi
  done < "$TARGETS_FILE"

  rm -f "$images_file"
  if [[ "$selected" -eq 0 ]]; then
    printf 'No unpassed rows selected for image preflight.\n'
    return 0
  fi
  if [[ "$missing" -gt 0 ]]; then
    printf 'Error: %s of %s selected image(s) are missing in Prism.\n' "$missing" "$selected" >&2
    return 1
  fi
  printf 'Image preflight passed: %s selected image(s) are present in Prism.\n' "$selected"
}

validate_row_filter_exists() {
  [[ -n "$ROW_FILTER" ]] || return 0

  local ndb_version db_type os_type os_version db_version mongodb_edition mongodb_deployments image_name image_uuid finished_at
  local row_id
  while IFS='|' read -r ndb_version db_type os_type os_version db_version mongodb_edition mongodb_deployments image_name image_uuid finished_at; do
    [[ -n "$DB_TYPE_FILTER" && "$db_type" != "$DB_TYPE_FILTER" ]] && continue
    row_id=$(row_id_for "$ndb_version" "$db_type" "$os_type" "$os_version" "$db_version" "$mongodb_edition" "$mongodb_deployments")
    if [[ "$row_id" == "$ROW_FILTER" ]]; then
      return 0
    fi
  done < "$TARGETS_FILE"

  printf 'Error: --row-id did not match any generated E2E target after current filters: %q\n' "$ROW_FILTER" >&2
  printf 'Generated targets require a buildable matrix row and a latest successful manifest. Run --dry-run without --row-id to list available row IDs.\n' >&2
  return 1
}

run_target() {
  local index=$1 ndb_version=$2 db_type=$3 os_type=$4 os_version=$5 db_version=$6 mongodb_edition=$7 mongodb_deployments=$8 image_name=$9 image_uuid=${10}
  local row_id short_key run_id row_dir state_file db_name vm_name profile_name provision_ip
  row_id=$(row_id_for "$ndb_version" "$db_type" "$os_type" "$os_version" "$db_version" "$mongodb_edition" "$mongodb_deployments")
  short_key=$(short_row_key "$row_id")
  run_id=$(date +%m%d%H%M%S)
  row_dir="$STATE_DIR/${row_id}-${run_id}"
  state_file="$row_dir/state.json"
  CURRENT_STATE_FILE="$state_file"
  mkdir -p "$row_dir"
  chmod 700 "$row_dir"

  printf '\n=== E2E target %s (%s/%s %s %s %s) ===\n' "$row_id" "$index" "$db_type" "$db_version" "$os_type" "$os_version"
  if [[ "$DRY_RUN" == "true" ]]; then
    printf 'DRY RUN: image=%s uuid=%s deployments=%s\n' "$image_name" "$image_uuid" "$mongodb_deployments"
    return 0
  fi

  create_source_vm "$state_file" "$row_id" "$image_name" "$image_uuid" "$db_version" "$db_type"
  prepare_common_source_vm "$state_file"
  if [[ "$db_type" == "pgsql" ]]; then
    prepare_postgres_source_vm "$state_file" "$os_type" "$db_version"
  else
    prepare_mongodb_source_vm "$state_file" "$db_version"
  fi

  register_dbserver "$state_file" "$db_type" "$row_dir/register-dbserver-payload.json" "$row_dir/register-dbserver-response.json" "$row_dir/register-dbserver-operation.json"
  prepare_debian_ndb_dm_serial_metadata "$state_file" "$os_type"
  profile_name="CODEX_E2E_${short_key}_${run_id}"
  create_software_profile "$state_file" "$db_type" "$os_type" "$os_version" "$profile_name" "$row_dir/profile-payload.json" "$row_dir/profile-response.json" "$row_dir/profile-operation.json"

  db_name="e2e${run_id}$(printf '%s' "$row_id" | cksum | cut -d' ' -f1 | cut -c1-8)"
  vm_name="ndb-e2e-db-${short_key}-${run_id}"
  provision_database "$state_file" "$db_type" "$db_name" "$vm_name" "$row_dir/provision-payload.json" "$row_dir/provision-response.json" "$row_dir/provision-operation.json"
  provision_ip=$(extract_provisioned_ip "$row_dir/provision-operation.json")
  if [[ -z "$provision_ip" ]]; then
    printf 'Error: could not extract provisioned VM IP from operation.\n' >&2
    return 1
  fi
  jq --arg provisioned_vm_ip "$provision_ip" \
    '. + {provisioned_vm_ip: $provisioned_vm_ip}' "$state_file" > "${state_file}.tmp"
  mv "${state_file}.tmp" "$state_file"
  validate_guest_database "$state_file" "$db_type" "$provision_ip"
  record_result "$state_file" pass ""
  CURRENT_STATE_FILE=""
}

main() {
  DELETE_VM_ON_FAILURE=$(normalize_json_bool "$DELETE_VM_ON_FAILURE" NDB_E2E_DELETE_VM_ON_FAILURE)
  TARGET_OBSERVER=$(normalize_json_bool "$TARGET_OBSERVER" NDB_E2E_TARGET_OBSERVER)
  if ! [[ "$TARGET_OBSERVER_INTERVAL_SECONDS" =~ ^[0-9]+$ ]] || (( TARGET_OBSERVER_INTERVAL_SECONDS < 1 )); then
    printf 'Error: NDB_E2E_TARGET_OBSERVER_INTERVAL_SECONDS must be a positive integer.\n' >&2
    return 1
  fi
  if ! [[ "$TARGET_OBSERVER_MAX_SECONDS" =~ ^[0-9]+$ ]] || (( TARGET_OBSERVER_MAX_SECONDS < 1 )); then
    printf 'Error: NDB_E2E_TARGET_OBSERVER_MAX_SECONDS must be a positive integer.\n' >&2
    return 1
  fi

  if [[ "$DRY_RUN" != "true" ]]; then
    if ! [[ "$NDB_POSTGRES_SOFTWARE_DISK_SIZE_GB" =~ ^[0-9]+$ ]] || (( NDB_POSTGRES_SOFTWARE_DISK_SIZE_GB < 1 )); then
      printf 'Error: NDB_E2E_POSTGRES_SOFTWARE_DISK_SIZE_GB must be a positive integer.\n' >&2
      return 1
    fi
    if ! [[ "$NDB_API_TIMEOUT" =~ ^[0-9]+$ ]] || (( NDB_API_TIMEOUT < 1 )); then
      printf 'Error: NDB_E2E_NDB_API_TIMEOUT must be a positive integer.\n' >&2
      return 1
    fi
    require_env NDB_SERVER_ADDRESS NDB_SERVER_USER NDB_SERVER_PASSWORD PKR_VAR_pc_username PKR_VAR_pc_password PKR_VAR_pc_ip PKR_VAR_cluster_name PKR_VAR_subnet_name
    require_file "$PRIVATE_KEY_PATH"
    require_file "$PUBLIC_KEY_PATH"
    require_file "$USER_DATA_TEMPLATE"
    mkdir -p "$STATE_DIR"
    chmod 700 "$STATE_DIR"
    touch "$EVIDENCE_FILE"
    chmod 600 "$EVIDENCE_FILE"
  fi

  generate_targets
  local total expected
  total=$(wc -l < "$TARGETS_FILE" | tr -d ' ')
  expected=$(expected_target_count)
  if [[ "$total" != "$expected" ]]; then
    printf 'Error: expected %s latest-success targets from the buildable matrix, got %s.\n' "$expected" "$total" >&2
    return 1
  fi
  validate_row_filter_exists
  if [[ "$DRY_RUN" != "true" ]]; then
    preflight_target_images
    if [[ "$PREFLIGHT_IMAGES" == "true" ]]; then
      return 0
    fi
  fi

  local attempted=0 index=0
  while IFS='|' read -r ndb_version db_type os_type os_version db_version mongodb_edition mongodb_deployments image_name image_uuid finished_at; do
    index=$((index + 1))
    [[ -n "$DB_TYPE_FILTER" && "$db_type" != "$DB_TYPE_FILTER" ]] && continue
    local row_id
    row_id=$(row_id_for "$ndb_version" "$db_type" "$os_type" "$os_version" "$db_version" "$mongodb_edition" "$mongodb_deployments")
    [[ -n "$ROW_FILTER" && "$row_id" != "$ROW_FILTER" ]] && continue
    if [[ "$DRY_RUN" != "true" && "$RERUN_PASSED" != "true" ]] && row_already_passed "$row_id"; then
      printf 'Skipping already passed row: %s\n' "$row_id"
      continue
    fi
    attempted=$((attempted + 1))
    run_target "$index" "$ndb_version" "$db_type" "$os_type" "$os_version" "$db_version" "$mongodb_edition" "$mongodb_deployments" "$image_name" "$image_uuid"
    if [[ "$LIMIT" -gt 0 && "$attempted" -ge "$LIMIT" ]]; then
      break
    fi
  done < "$TARGETS_FILE"

  printf 'Attempted rows: %s\n' "$attempted"
}

main "$@"
