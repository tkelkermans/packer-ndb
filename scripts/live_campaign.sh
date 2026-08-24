#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/args.sh
source "$ROOT_DIR/scripts/args.sh"

ENV_FILE="${NDB_ENV_FILE:-$ROOT_DIR/.env}"
DRY_RUN=false
EXECUTE=false
PREFLIGHT_ONLY=false
ALLOW_RHEL=false
PHASE_FILTER=""
FROM_PHASE=1
STOP_AFTER_PHASE=0
SKIP_E2E=false
CHECK_LAB=false
NDB_VERSION_DEFAULT="2.10"

log() {
  printf '%s\n' "$*" >&2
}

usage() {
  cat <<'EOF'
Usage: scripts/live_campaign.sh [options]

Runs the recommended live validation campaign from VALIDATION.md in order.
Each phase uses build.sh with --validate --validate-artifact --manifest unless
noted. E2E steps call scripts/ndb_e2e_validate.sh (serialized; one NDB server).

By default this prints the planned commands (--dry-run). Pass --execute to run
them through a single serialized wrapper:

  op run --env-file=.env -- scripts/live_campaign.sh --execute --phase 1

Never run two op run wrappers in parallel against the same .env FIFO.

Phases:
  1  ubuntu_pg18_e2e     Ubuntu 24.04 / PostgreSQL 18 build (if needed) + NDB E2E
  2  debian_pg_smoke     Debian 12 / PostgreSQL 18 build + optional E2E (known blocker)
  3  rocky_mongo_smoke   Rocky 9.7 MongoDB 7.0 and 8.0 smoke builds
  4  ndb_211_smoke       NDB 2.11 first buildable row per OS (RHEL skipped unless --allow-rhel)
  5  debian_mongo        NDB 2.11 Debian 12 / MongoDB 7.0 Community smoke build

Options:
  --list-phases         Print phase numbers and names, then exit
  --phase NAME|NUM      Run only one phase (name or 1-5)
  --from-phase NUM      Start at this phase (default: 1)
  --stop-after NUM      Stop after this phase
  --preflight           Run Prism/source-image preflight only (no Packer/E2E)
  --execute             Run commands (requires lab credentials via op run)
  --dry-run             Print commands only (default when --execute omitted)
  --skip-e2e            Skip NDB E2E steps in phases that support them
  --allow-rhel          Include RHEL rows in phase 4
  --env-file PATH       Alternate .env path (default: repo-root .env)
  --check-lab           Verify local tools, keys, and required env vars; exit 0/1
  -h, --help            Show this help and exit
EOF
}

REQUIRED_PRISM_VARS=(
  PKR_VAR_pc_username
  PKR_VAR_pc_password
  PKR_VAR_pc_ip
  PKR_VAR_cluster_name
  PKR_VAR_subnet_name
)
REQUIRED_E2E_VARS=(
  NDB_SERVER_ADDRESS
  NDB_SERVER_USER
  NDB_SERVER_PASSWORD
  NDB_E2E_CLUSTER_ID
  NDB_E2E_COMPUTE_PROFILE_ID
  NDB_E2E_SLA_ID
  NDB_E2E_POSTGRES_NETWORK_PROFILE_ID
  NDB_E2E_POSTGRES_DB_PARAM_PROFILE_ID
)

check_lab_readiness() {
  local missing=0
  local var

  for cmd in bash jq curl packer ansible-playbook; do
    if command -v "$cmd" >/dev/null 2>&1; then
      log "  ok: command ${cmd}"
    else
      log "  missing: command ${cmd}"
      missing=$((missing + 1))
    fi
  done

  if [[ -f "$ROOT_DIR/packer/id_rsa" && -f "$ROOT_DIR/packer/id_rsa.pub" ]]; then
    log "  ok: packer/id_rsa key pair"
  else
    log "  missing: packer/id_rsa (run: ssh-keygen -t rsa -b 4096 -f packer/id_rsa -N \"\")"
    missing=$((missing + 1))
  fi

  if packer init "$ROOT_DIR/packer/" >/dev/null 2>&1; then
    log "  ok: packer init"
  else
    log "  missing: packer plugins (run: packer init packer/)"
    missing=$((missing + 1))
  fi

  if [[ -f "$ENV_FILE" ]]; then
    log "  ok: env file present at ${ENV_FILE}"
  elif [[ -n "${PKR_VAR_pc_ip:-}" ]]; then
    log "  ok: Prism env vars exported in shell"
  else
    log "  missing: ${ENV_FILE} or exported PKR_VAR_pc_ip (wire 1Password or export lab env)"
    missing=$((missing + 1))
  fi

  for var in "${REQUIRED_PRISM_VARS[@]}"; do
    if [[ -n "${!var:-}" ]]; then
      log "  ok: ${var}=set"
    else
      log "  missing: ${var}"
      missing=$((missing + 1))
    fi
  done

  if [[ "$SKIP_E2E" != "true" && "$PREFLIGHT_ONLY" != "true" ]]; then
    for var in "${REQUIRED_E2E_VARS[@]}"; do
      if [[ -n "${!var:-}" ]]; then
        log "  ok: ${var}=set"
      else
        log "  missing: ${var} (required for E2E phases; use --skip-e2e or --preflight to omit)"
        missing=$((missing + 1))
      fi
    done
  fi

  if (( missing > 0 )); then
    log ""
    log "Lab readiness: incomplete (${missing} gap(s))"
    return 1
  fi

  log ""
  log "Lab readiness: complete"
  return 0
}

run_cmd() {
  local description=$1
  shift
  log ""
  log "==> $description"
  log "    $*"
  if [[ "$DRY_RUN" == "true" ]]; then
    return 0
  fi
  if [[ "$EXECUTE" != "true" ]]; then
    return 0
  fi
  (
    cd "$ROOT_DIR"
    "$@"
  )
}

build_row() {
  local ndb_version=$1 db_type=$2 os_type=$3 os_version=$4 db_version=$5
  local args=(
    "$ROOT_DIR/build.sh" --ci
    --validate --validate-artifact --manifest
    --ndb-version "$ndb_version"
    --db-type "$db_type"
    --os "$os_type"
    --os-version "$os_version"
    --db-version "$db_version"
  )
  run_cmd "Build ${ndb_version} ${db_type} on ${os_type} ${os_version} (DB ${db_version})" "${args[@]}"
}

preflight_row() {
  local ndb_version=$1 db_type=$2 os_type=$3 os_version=$4 db_version=$5
  local args=(
    "$ROOT_DIR/build.sh" --ci --preflight
    --ndb-version "$ndb_version"
    --db-type "$db_type"
    --os "$os_type"
    --os-version "$os_version"
    --db-version "$db_version"
  )
  run_cmd "Preflight ${ndb_version} ${db_type} on ${os_type} ${os_version} (DB ${db_version})" "${args[@]}"
}

run_e2e_row() {
  local row_id=$1
  local extra_args=()
  if [[ $# -gt 1 ]]; then
    extra_args+=("${@:2}")
  fi
  run_cmd "NDB E2E row ${row_id}" \
    "$ROOT_DIR/scripts/ndb_e2e_validate.sh" --row-id "$row_id" --limit 1 "${extra_args[@]}"
}

run_e2e_preflight_images() {
  run_cmd "NDB E2E image preflight" \
    "$ROOT_DIR/scripts/ndb_e2e_validate.sh" --preflight-images
}

phase_ubuntu_pg18_e2e() {
  log "Phase 1: Ubuntu 24.04 / PostgreSQL 18 NDB E2E"
  if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
    preflight_row "$NDB_VERSION_DEFAULT" pgsql "Ubuntu Linux" 24.04 18
    return 0
  fi
  build_row "$NDB_VERSION_DEFAULT" pgsql "Ubuntu Linux" 24.04 18
  if [[ "$SKIP_E2E" != "true" ]]; then
    run_e2e_preflight_images
    run_e2e_row "210-pg18-ubuntu2404"
  fi
}

phase_debian_pg_smoke() {
  log "Phase 2: Debian 12 / PostgreSQL 18 (expect known NDB storage/protection blocker on E2E)"
  if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
    preflight_row "$NDB_VERSION_DEFAULT" pgsql Debian 12 18
    return 0
  fi
  build_row "$NDB_VERSION_DEFAULT" pgsql Debian 12 18
  if [[ "$SKIP_E2E" != "true" ]]; then
    run_e2e_preflight_images
    run_e2e_row "210-pg18-debian12"
  fi
}

phase_rocky_mongo_smoke() {
  log "Phase 3: Rocky Linux 9.7 MongoDB 7.0 and 8.0 smoke"
  if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
    preflight_row "$NDB_VERSION_DEFAULT" mongodb "Rocky Linux" 9.7 7.0
    preflight_row "$NDB_VERSION_DEFAULT" mongodb "Rocky Linux" 9.7 8.0
    return 0
  fi
  build_row "$NDB_VERSION_DEFAULT" mongodb "Rocky Linux" 9.7 7.0
  build_row "$NDB_VERSION_DEFAULT" mongodb "Rocky Linux" 9.7 8.0
}

phase_ndb_211_smoke() {
  local rows_file
  rows_file=$(mktemp -t ndb-211-smoke.XXXXXX)
  jq -r '
    [.[] | select((.provisioning_role // "postgresql") != "metadata")]
    | group_by(.os_type)
    | .[]
    | .[0]
    | [.ndb_version, .db_type, .os_type, .os_version, (.db_version|tostring)]
    | @tsv
  ' "$ROOT_DIR/ndb/2.11/matrix.json" >"$rows_file"

  log "Phase 4: NDB 2.11 first buildable row per OS ($(wc -l <"$rows_file" | tr -d ' ') rows)"
  while IFS=$'\t' read -r ndb_version db_type os_type os_version db_version; do
    case "$os_type" in
      RHEL|"Red Hat Enterprise Linux (RHEL)")
        if [[ "$ALLOW_RHEL" != "true" ]]; then
          log "    Skipping RHEL row ${os_version} / ${db_type} ${db_version} (use --allow-rhel after issue #2)"
          continue
        fi
        ;;
    esac
    if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
      preflight_row "$ndb_version" "$db_type" "$os_type" "$os_version" "$db_version"
    else
      build_row "$ndb_version" "$db_type" "$os_type" "$os_version" "$db_version"
    fi
  done <"$rows_file"
  rm -f "$rows_file"
}

phase_debian_mongo() {
  log "Phase 5: NDB 2.11 Debian 12 / MongoDB 7.0 Community (never built here)"
  if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
    preflight_row 2.11 mongodb Debian 12 7.0
    return 0
  fi
  build_row 2.11 mongodb Debian 12 7.0
}

declare -a PHASE_NAMES=(
  ubuntu_pg18_e2e
  debian_pg_smoke
  rocky_mongo_smoke
  ndb_211_smoke
  debian_mongo
)

phase_selected() {
  local index=$1
  local name=${PHASE_NAMES[$((index - 1))]}

  if [[ -n "$PHASE_FILTER" ]]; then
    [[ "$PHASE_FILTER" == "$name" || "$PHASE_FILTER" == "$index" ]]
    return
  fi
  if (( index < FROM_PHASE )); then
    return 1
  fi
  if (( STOP_AFTER_PHASE > 0 && index > STOP_AFTER_PHASE )); then
    return 1
  fi
  return 0
}

run_phases() {
  local index=1
  for name in "${PHASE_NAMES[@]}"; do
    if phase_selected "$index"; then
      case "$name" in
        ubuntu_pg18_e2e) phase_ubuntu_pg18_e2e ;;
        debian_pg_smoke) phase_debian_pg_smoke ;;
        rocky_mongo_smoke) phase_rocky_mongo_smoke ;;
        ndb_211_smoke) phase_ndb_211_smoke ;;
        debian_mongo) phase_debian_mongo ;;
      esac
    fi
    index=$((index + 1))
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list-phases)
      printf '1 ubuntu_pg18_e2e\n2 debian_pg_smoke\n3 rocky_mongo_smoke\n4 ndb_211_smoke\n5 debian_mongo\n'
      exit 0
      ;;
    --phase)
      require_option_value "$1" "$#"
      PHASE_FILTER=$2
      shift
      ;;
    --from-phase)
      require_option_value "$1" "$#"
      require_numeric_option_value "$1" "$2"
      FROM_PHASE=$2
      shift
      ;;
    --stop-after)
      require_option_value "$1" "$#"
      require_numeric_option_value "$1" "$2"
      STOP_AFTER_PHASE=$2
      shift
      ;;
    --preflight)
      PREFLIGHT_ONLY=true
      ;;
    --execute)
      EXECUTE=true
      DRY_RUN=false
      ;;
    --dry-run)
      DRY_RUN=true
      EXECUTE=false
      ;;
    --skip-e2e)
      SKIP_E2E=true
      ;;
    --allow-rhel)
      ALLOW_RHEL=true
      ;;
    --check-lab)
      CHECK_LAB=true
      ;;
    --env-file)
      require_option_value "$1" "$#"
      ENV_FILE=$2
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log "Unknown option: $1"
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$EXECUTE" != "true" && "$DRY_RUN" != "true" ]]; then
  DRY_RUN=true
fi

if [[ "$CHECK_LAB" == "true" ]]; then
  export PKR_VAR_nutanix_insecure="${PKR_VAR_nutanix_insecure:-true}"
  log "Checking lab readiness for live campaign..."
  check_lab_readiness
  exit $?
fi

if [[ "$EXECUTE" == "true" ]]; then
  export PKR_VAR_nutanix_insecure="${PKR_VAR_nutanix_insecure:-true}"
  export PKR_VAR_vm_cpu="${PKR_VAR_vm_cpu:-2}"
  export PKR_VAR_vm_memory_mb="${PKR_VAR_vm_memory_mb:-4096}"
  export PKR_VAR_vm_disk_size_gb="${PKR_VAR_vm_disk_size_gb:-40}"
  if [[ ! -f "$ENV_FILE" ]] && [[ -z "${PKR_VAR_pc_ip:-}" ]]; then
    log "Error: --execute requires credentials at ${ENV_FILE} or exported PKR_VAR_* env vars."
    log "Wire 1Password, then run exactly one serialized wrapper, for example:"
    log "  op run --env-file=${ENV_FILE} -- scripts/live_campaign.sh --execute --phase 1"
    exit 1
  fi
fi

log "Live campaign plan (VALIDATION.md order)"
if [[ "$EXECUTE" == "true" ]]; then
  log "  mode: execute"
elif [[ "$DRY_RUN" == "true" ]]; then
  log "  mode: dry-run"
else
  log "  mode: plan"
fi
if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
  log "  preflight-only: yes"
fi
log "  from phase: ${FROM_PHASE}"
if (( STOP_AFTER_PHASE > 0 )); then
  log "  stop after phase: ${STOP_AFTER_PHASE}"
fi
if [[ -n "$PHASE_FILTER" ]]; then
  log "  phase filter: ${PHASE_FILTER}"
fi

run_phases

if [[ "$DRY_RUN" == "true" && "$EXECUTE" != "true" ]]; then
  log ""
  log "Dry run complete. To run phase 1 against your lab:"
  log "  op run --env-file=${ENV_FILE} -- scripts/live_campaign.sh --execute --phase 1"
fi
