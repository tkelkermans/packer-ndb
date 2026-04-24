#!/bin/bash

# Master build script for NDB Packer images

TEMP_FILES=()

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MANIFEST_HELPER="${SCRIPT_DIR}/scripts/manifest.sh"
# shellcheck source=scripts/source_images.sh
source "${SCRIPT_DIR}/scripts/source_images.sh"

REQUIRED_ENV_VARS=(
  "PKR_VAR_pc_username"
  "PKR_VAR_pc_password"
  "PKR_VAR_pc_ip"
  "PKR_VAR_cluster_name"
  "PKR_VAR_subnet_name"
)

COMMON_REQUIRED_COMMANDS=(
  "jq"
)

LIVE_REQUIRED_COMMANDS=(
  "packer"
  "curl"
)

function cleanup() {
  if (( ${#TEMP_FILES[@]} > 0 )); then
    for file in "${TEMP_FILES[@]}"; do
      [[ -f "$file" ]] && rm -f "$file"
    done
  fi
}

function on_exit() {
  local status=$?
  if [[ "$status" -ne 0 && "${MANIFEST_FINALIZED:-false}" != "true" && -n "${MANIFEST_FILE:-}" && -f "${MANIFEST_FILE:-}" ]]; then
    if [[ -n "${PACKER_STARTED_EPOCH:-}" ]]; then
      local failed_at failed_epoch
      failed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
      failed_epoch=$(date +%s)
      if [[ -z "${PACKER_FINISHED_EPOCH:-}" ]]; then
        "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".packer.finished_at" --value "$failed_at" >/dev/null 2>&1 || true
        "$MANIFEST_HELPER" set-json --file "$MANIFEST_FILE" --key ".packer.duration_seconds" --json-value "$((failed_epoch - PACKER_STARTED_EPOCH))" >/dev/null 2>&1 || true
      fi
    fi
    "$MANIFEST_HELPER" finalize --file "$MANIFEST_FILE" --status failed >/dev/null 2>&1 || true
  fi
  cleanup
  exit "$status"
}
trap on_exit EXIT

function usage() {
  cat <<'EOF'
Usage: ./build.sh [options]

Options:
  --ci                      Run non-interactively
  --dry-run                 Resolve inputs and show the planned build without invoking Packer
  --preflight               Check live Prism/source-image readiness without invoking Packer
  --stage-source            Import a remote source image into Prism before invoking Packer
  --validate                Run in-guest validation checks after provisioning and fail the build on validation errors
  --validate-artifact       Boot the saved image in a disposable VM and validate it after Packer succeeds
  --manifest                Write a build manifest under manifests/ for live builds
  --debug                   Enable PACKER_LOG and interactive Packer debug mode
  --ndb-version VERSION     NDB version to build
  --db-type TYPE            Database type to build
  --os NAME                 Operating system name from matrix.json
  --os-version VERSION      Operating system version from matrix.json
  --db-version VERSION      Database version from matrix.json
  --source-image-uri URI    Override images.json with an explicit source image URI or local file path
  --source-image-name NAME  Override images.json with the name of an image that already exists in Prism
  -h, --help                Show this help and exit

Environment:
  SKIP_MATRIX_VALIDATION=true  Skip matrix validation (not recommended)
EOF
}

function command_is_available() {
  command -v "$1" >/dev/null 2>&1
}

function require_env_vars() {
  local missing=()
  for var_name in "${REQUIRED_ENV_VARS[@]}"; do
    if [[ -z "${!var_name:-}" ]]; then
      missing+=("$var_name")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    echo "Error: Required environment variables are not set: ${missing[*]}" >&2
    exit 1
  fi
}

function require_commands() {
  local missing=()
  for cmd in "$@"; do
    if ! command_is_available "$cmd"; then
      missing+=("$cmd")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    echo "Error: The following commands are required but not installed: ${missing[*]}" >&2
    exit 1
  fi
}

function ensure_file_exists() {
  local path=$1
  if [[ ! -f "$path" ]]; then
    echo "Error: Required file '${path}' not found." >&2
    exit 1
  fi
}

function validate_matrix_file() {
  local matrix_file=$1
  if [[ "${SKIP_MATRIX_VALIDATION:-false}" == "true" ]]; then
    return
  fi
  scripts/matrix_validate.sh "$matrix_file"
}

function normalize_image_key_part() {
  source_image_normalize_key_part "$1"
}

function image_key_for_os() {
  local os_type=$1
  local os_version=$2

  source_image_key_for_os "$os_type" "$os_version"
}

function resolve_image_source() {
  local image_key=$1
  local images_file=$2

  ensure_file_exists "$images_file"
  source_image_resolve_from_images_json "$images_file" "$image_key"
}

function image_entry_prefetch() {
  local image_key=$1
  local images_file=$2
  jq -r --arg key "$image_key" \
    'if has($key) and (.[$key] | type) == "object" then ((.[$key].prefetch // false) | if . then "true" else "false" end) else "false" end' \
    "$images_file"
}

function image_entry_type() {
  local image_key=$1
  local images_file=$2
  jq -r --arg key "$image_key" 'if has($key) then (.[$key] | type) else "missing" end' "$images_file"
}

function image_entry_field() {
  local image_key=$1
  local images_file=$2
  local field_name=$3
  jq -r --arg key "$image_key" --arg field_name "$field_name" '.[$key][$field_name] // ""' "$images_file"
}

function materialize_source_image() {
  local source_image=$1
  local prefetch=${2:-false}
  local temp_image

  if [[ "$source_image" =~ ^file:// ]]; then
    echo "$source_image"
    return
  fi

  if [[ -f "$source_image" ]]; then
    echo "file://${source_image}"
    return
  fi

  if [[ "$prefetch" == "true" ]]; then
    temp_image=$(mktemp -t ndb-source-image.XXXXXX)
    TEMP_FILES+=("$temp_image")
    echo "--- Downloading source image locally ---" >&2
    curl -fL -o "$temp_image" "$source_image"
    echo "file://${temp_image}"
    return
  fi

  echo "$source_image"
}

function slugify() {
  normalize_image_key_part "$1"
}

function generate_ansible_vars_json() {
  local ndb_version=$1
  local db_version=$2
  local extensions_json=$3
  local db_type=$4
  local validate_build=$5

  jq -nc \
    --arg db_version "$db_version" \
    --arg db_type "$db_type" \
    --arg ndb_version "$ndb_version" \
    --argjson validate_build "$validate_build" \
    --argjson postgres_extensions "${extensions_json:-[]}" \
    '{
      db_version: $db_version,
      db_type: $db_type,
      ndb_version: $ndb_version,
      validate_build: $validate_build,
      postgres_extensions: $postgres_extensions
    }'
}

function write_ansible_vars_file() {
  local ansible_vars_json=$1
  local vars_file
  vars_file=$(mktemp -t ndb-ansible-vars.XXXXXX.json)
  printf '%s\n' "$ansible_vars_json" > "$vars_file"
  TEMP_FILES+=("$vars_file")
  echo "$vars_file"
}

function print_dry_run_summary() {
  local live_ready=true
  local missing_items=()
  local config_pretty
  local ansible_vars_pretty

  for cmd in "${LIVE_REQUIRED_COMMANDS[@]}"; do
    if ! command_is_available "$cmd"; then
      live_ready=false
      missing_items+=("command: ${cmd}")
    fi
  done
  if [[ "$VALIDATE_ARTIFACT" == "true" ]]; then
    for cmd in ssh ansible-playbook base64; do
      if ! command_is_available "$cmd"; then
        live_ready=false
        missing_items+=("command: ${cmd}")
      fi
    done
  fi

  for var_name in "${REQUIRED_ENV_VARS[@]}"; do
    if [[ -z "${!var_name:-}" ]]; then
      live_ready=false
      missing_items+=("env var: ${var_name}")
    fi
  done

  if [[ ! -f "$PUBLIC_KEY_PATH" ]]; then
    live_ready=false
    missing_items+=("file: ${PUBLIC_KEY_PATH}")
  fi

  if [[ "$SOURCE_IMAGE_RESOLUTION_STATUS" == "missing-env" ]]; then
    live_ready=false
    missing_items+=("env var: ${SOURCE_IMAGE_REQUIRED_ENV_VAR} (source image for ${IMAGE_KEY})")
  fi

  config_pretty=$(printf '%s\n' "$CONFIG" | jq '.')
  ansible_vars_pretty=$(printf '%s\n' "$ANSIBLE_VARS_JSON" | jq '.')

  cat <<EOF
=== NDB Build Dry Run ===
Mode: ${MODE}
Debug: ${DEBUG}
Validate after provisioning: ${VALIDATE_BUILD}
Validate saved artifact: ${VALIDATE_ARTIFACT}
Ready for live build: $( [[ "$live_ready" == "true" ]] && echo "yes" || echo "no" )

Selection:
  NDB version: ${NDB_VERSION}
  Engine: ${ENGINE_NAME:-$DB_TYPE}
  DB type: ${DB_TYPE}
  DB version: ${DB_VERSION}
  OS: ${OS_TYPE} ${OS_VERSION}
  Provisioning role: ${PROVISIONING_ROLE}

Resolved files:
  Matrix file: ${MATRIX_FILE}
  Ansible playbook: ${ANSIBLE_SITE_PLAYBOOK}
  Ansible config: ${ANSIBLE_CFG_PATH}
  SSH public key: ${PUBLIC_KEY_PATH} ($( [[ -f "$PUBLIC_KEY_PATH" ]] && echo "present" || echo "missing" ))

Source image:
  Images file: ${IMAGES_FILE}
  Image key: ${IMAGE_KEY:-<override>}
  Override provided: $( [[ -n "$SOURCE_IMAGE_URI_OVERRIDE" || -n "$SOURCE_IMAGE_NAME_OVERRIDE" ]] && echo "yes" || echo "no" )
  Resolution status: ${SOURCE_IMAGE_RESOLUTION_STATUS}
  Raw source image input: ${SOURCE_IMAGE_RAW_DISPLAY}
  Prefetch before packer: ${PREFETCH_SOURCE_IMAGE}
  Effective packer source_image_name: ${PACKER_SOURCE_IMAGE_NAME}
  Effective packer source_image_uri: ${PACKER_SOURCE_IMAGE_URI}
  Effective packer source_image_path: ${PACKER_SOURCE_IMAGE_PATH}
  Runtime action: ${SOURCE_IMAGE_RUNTIME_ACTION}
EOF

  if [[ -n "${SOURCE_IMAGE_REQUIRED_ENV_VAR:-}" ]]; then
    printf '  Source image env var: %s (%s)\n' \
      "$SOURCE_IMAGE_REQUIRED_ENV_VAR" \
      "$( [[ -n "${!SOURCE_IMAGE_REQUIRED_ENV_VAR:-}" ]] && echo "present" || echo "missing" )"
  fi

  if [[ -n "${SOURCE_IMAGE_DESCRIPTION:-}" ]]; then
    printf '  Source image note: %s\n' "$SOURCE_IMAGE_DESCRIPTION"
  fi

  cat <<EOF

Generated identifiers:
  Image name: ${IMAGE_NAME}
  VM name: ${VM_NAME}

Generated Ansible vars:
${ansible_vars_pretty}

Selected matrix entry:
${config_pretty}

Packer variable preview:
  ansible_site_playbook=${ANSIBLE_SITE_PLAYBOOK}
  ansible_config_path=${ANSIBLE_CONFIG_PATH}
  ansible_extra_vars_file=<temporary file created at runtime>
  ndb_version=${NDB_VERSION}
  os_type=${OS_TYPE}
  os_version=${OS_VERSION}
  db_type=${DB_TYPE}
  db_version=${DB_VERSION}
  patroni_version=${PATRONI_VERSION}
  etcd_version=${ETCD_VERSION}
  source_image_name=${PACKER_SOURCE_IMAGE_NAME}
  source_image_uri=${PACKER_SOURCE_IMAGE_URI}
  source_image_path=${PACKER_SOURCE_IMAGE_PATH}
  image_name=${IMAGE_NAME}
  vm_name=${VM_NAME}
  ssh_public_key=<contents of ${PUBLIC_KEY_PATH}>

Environment prerequisite status:
EOF

  for var_name in "${REQUIRED_ENV_VARS[@]}"; do
    printf '  %s=%s\n' "$var_name" "$( [[ -n "${!var_name:-}" ]] && echo "present" || echo "missing" )"
  done

  printf '\nCommand prerequisite status:\n'
  for cmd in "${COMMON_REQUIRED_COMMANDS[@]}" "${LIVE_REQUIRED_COMMANDS[@]}"; do
    printf '  %s=%s\n' "$cmd" "$( command_is_available "$cmd" && echo "present" || echo "missing" )"
  done
  if [[ "$VALIDATE_ARTIFACT" == "true" ]]; then
    for cmd in ssh ansible-playbook base64; do
      printf '  %s=%s\n' "$cmd" "$( command_is_available "$cmd" && echo "present" || echo "missing" )"
    done
  fi

  if (( ${#missing_items[@]} > 0 )); then
    printf '\nMissing live-build prerequisites:\n'
    for item in "${missing_items[@]}"; do
      printf '  - %s\n' "$item"
    done
  fi
}

function select_from_list() {
  local item_type=$1
  shift
  local items=("$@")

  if (( ${#items[@]} == 0 )); then
    echo "Error: No ${item_type}s available for selection." >&2
    exit 1
  fi

  echo "Available ${item_type}s:" >&2
  select item in "${items[@]}"; do
    if [[ -n "$item" ]]; then
      echo "$item"
      break
    else
      echo "Invalid selection. Please try again." >&2
    fi
  done
}

MODE="interactive"
DEBUG=false
DRY_RUN=false
PREFLIGHT_ONLY=false
STAGE_SOURCE=false
VALIDATE_BUILD=false
VALIDATE_ARTIFACT=false
WRITE_MANIFEST=false
MANIFEST_FILE=""
MANIFEST_FINALIZED=false

declare NDB_VERSION=""
declare OS_TYPE=""
declare OS_VERSION=""
declare DB_VERSION=""
declare DB_TYPE=""
declare SOURCE_IMAGE_URI_OVERRIDE=""
declare SOURCE_IMAGE_NAME_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --validate)
      VALIDATE_BUILD=true
      ;;
    --validate-artifact)
      VALIDATE_ARTIFACT=true
      ;;
    --manifest)
      WRITE_MANIFEST=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --preflight)
      PREFLIGHT_ONLY=true
      ;;
    --stage-source)
      STAGE_SOURCE=true
      ;;
    --debug)
      export PACKER_LOG=1
      DEBUG=true
      ;;
    --ci)
      MODE="ci"
      ;;
    --ndb-version)
      NDB_VERSION="$2"
      shift
      ;;
    --os)
      OS_TYPE="$2"
      shift
      ;;
    --os-version)
      OS_VERSION="$2"
      shift
      ;;
    --db-version)
      DB_VERSION="$2"
      shift
      ;;
    --db-type)
      DB_TYPE="$2"
      shift
      ;;
    --source-image-uri)
      SOURCE_IMAGE_URI_OVERRIDE="$2"
      shift
      ;;
    --source-image-name)
      SOURCE_IMAGE_NAME_OVERRIDE="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown parameter: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

require_commands "${COMMON_REQUIRED_COMMANDS[@]}"

if [[ "$DRY_RUN" != "true" ]]; then
  require_env_vars
  if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
    require_commands "curl"
  else
    require_commands "${LIVE_REQUIRED_COMMANDS[@]}"
    if [[ "$VALIDATE_ARTIFACT" == "true" ]]; then
      require_commands "ssh" "ansible-playbook" "base64"
    fi
  fi
fi

PUBLIC_KEY_PATH="packer/id_rsa.pub"
if [[ "$DRY_RUN" != "true" && "$PREFLIGHT_ONLY" != "true" ]]; then
  ensure_file_exists "$PUBLIC_KEY_PATH"
fi

if [[ "$MODE" == "ci" ]]; then
  if [[ -z "$NDB_VERSION" || -z "$OS_TYPE" || -z "$OS_VERSION" || -z "$DB_VERSION" || -z "$DB_TYPE" ]]; then
    echo "Error: --ci mode requires --ndb-version, --db-type, --os, --os-version, and --db-version." >&2
    exit 1
  fi
else
  NDB_VERSIONS=()
  while IFS= read -r line; do
    NDB_VERSIONS+=("$line")
  done < <(find ndb -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

  if [[ -z "$NDB_VERSION" ]]; then
    NDB_VERSION=$(select_from_list "NDB Version" "${NDB_VERSIONS[@]}")
  fi
fi

ANSIBLE_SITE_PLAYBOOK="ansible/${NDB_VERSION}/playbooks/site.yml"
ensure_file_exists "$ANSIBLE_SITE_PLAYBOOK"
ANSIBLE_CFG_PATH="ansible/${NDB_VERSION}/ansible.cfg"
ensure_file_exists "$ANSIBLE_CFG_PATH"
ANSIBLE_CONFIG_PATH="ANSIBLE_CONFIG=${ANSIBLE_CFG_PATH}"

MATRIX_FILE="ndb/${NDB_VERSION}/matrix.json"
if [[ ! -f "$MATRIX_FILE" ]]; then
  echo "Error: matrix.json not found for NDB version ${NDB_VERSION}. Please create it manually." >&2
  exit 1
fi
validate_matrix_file "$MATRIX_FILE"

if [[ "$MODE" != "ci" ]]; then
  if [[ -z "$DB_TYPE" ]]; then
    DB_TYPES=()
    while IFS= read -r line; do
      DB_TYPES+=("$line")
    done < <(jq -r '.[] | select((.provisioning_role // "postgresql") != "metadata") | .db_type' "$MATRIX_FILE" | sort -u)
    DB_TYPE=$(select_from_list "Database Type" "${DB_TYPES[@]}")
  fi

  if [[ -z "$OS_TYPE" ]]; then
    OS_TYPES=()
    while IFS= read -r line; do
      OS_TYPES+=("$line")
    done < <(jq -r --arg type "$DB_TYPE" '.[] | select(.db_type == $type and (.provisioning_role // "postgresql") != "metadata") | .os_type' "$MATRIX_FILE" | sort -u)
    OS_TYPE=$(select_from_list "OS" "${OS_TYPES[@]}")
  fi

  if [[ -z "$OS_VERSION" ]]; then
    OS_VERSIONS=()
    while IFS= read -r line; do
      OS_VERSIONS+=("$line")
    done < <(jq -r --arg type "$DB_TYPE" --arg os "$OS_TYPE" '.[] | select(.db_type == $type and .os_type == $os and (.provisioning_role // "postgresql") != "metadata") | .os_version' "$MATRIX_FILE" | sort -u)
    OS_VERSION=$(select_from_list "OS Version" "${OS_VERSIONS[@]}")
  fi

  if [[ -z "$DB_VERSION" ]]; then
    DB_VERSIONS=()
    while IFS= read -r line; do
      DB_VERSIONS+=("$line")
    done < <(jq -r --arg type "$DB_TYPE" --arg os "$OS_TYPE" --arg os_ver "$OS_VERSION" '.[] | select(.db_type == $type and .os_type == $os and .os_version == $os_ver and (.provisioning_role // "postgresql") != "metadata") | .db_version' "$MATRIX_FILE" | sort -u)
    DB_VERSION=$(select_from_list "DB Version" "${DB_VERSIONS[@]}")
  fi
fi

CONFIG=$(jq -ce --arg db_type "$DB_TYPE" --arg os "$OS_TYPE" --arg os_ver "$OS_VERSION" --arg db_ver "$DB_VERSION" \
  'first(.[] | select(.db_type == $db_type and .os_type == $os and .os_version == $os_ver and .db_version == $db_ver))' \
  "$MATRIX_FILE") || CONFIG=""

if [[ -z "$CONFIG" ]]; then
  echo "Error: No matching configuration found in matrix.json for the specified parameters." >&2
  exit 1
fi

POSTGRES_EXTENSIONS_JSON=$(echo "$CONFIG" | jq -c '.extensions // []')
ANSIBLE_VARS_JSON=$(generate_ansible_vars_json "$NDB_VERSION" "$DB_VERSION" "$POSTGRES_EXTENSIONS_JSON" "$DB_TYPE" "$VALIDATE_BUILD")
ENGINE_NAME=$(echo "$CONFIG" | jq -r '.engine // ""')
PROVISIONING_ROLE=$(echo "$CONFIG" | jq -r '.provisioning_role // "postgresql"')
if [[ "$PROVISIONING_ROLE" != "postgresql" ]]; then
  echo "Selected configuration (${ENGINE_NAME:-$DB_TYPE} on ${OS_TYPE} ${OS_VERSION}) is metadata-only (provisioning role: ${PROVISIONING_ROLE})." >&2
  echo "Current build pipeline supports only PostgreSQL entries. Please choose a PostgreSQL configuration." >&2
  exit 1
fi
PATRONI_VERSION=$(echo "$CONFIG" | jq -r '.patroni_version // .ha_components.patroni[0] // ""')
ETCD_VERSION=$(echo "$CONFIG" | jq -r '.etcd_version // .ha_components.etcd[0] // ""')

# --- Get Source Image URI ---
IMAGES_FILE="images.json"
SOURCE_IMAGE_RESOLUTION_STATUS="resolved"
SOURCE_IMAGE_REQUIRED_ENV_VAR=""
SOURCE_IMAGE_DESCRIPTION=""
SOURCE_IMAGE_RAW_DISPLAY=""
PACKER_SOURCE_IMAGE_NAME=""
PACKER_SOURCE_IMAGE_URI=""
PACKER_SOURCE_IMAGE_PATH=""
if [[ -n "$SOURCE_IMAGE_NAME_OVERRIDE" ]]; then
  PREFETCH_SOURCE_IMAGE=false
  SOURCE_IMAGE_RAW_DISPLAY="$SOURCE_IMAGE_NAME_OVERRIDE"
elif [[ -n "$SOURCE_IMAGE_URI_OVERRIDE" ]]; then
  SOURCE_IMAGE_URI="$SOURCE_IMAGE_URI_OVERRIDE"
  PREFETCH_SOURCE_IMAGE=false
  SOURCE_IMAGE_RAW_DISPLAY="$SOURCE_IMAGE_URI_OVERRIDE"
else
  IMAGE_KEY=$(image_key_for_os "$OS_TYPE" "$OS_VERSION")
  PREFETCH_SOURCE_IMAGE=$(image_entry_prefetch "$IMAGE_KEY" "$IMAGES_FILE")
  IMAGE_ENTRY_TYPE=$(image_entry_type "$IMAGE_KEY" "$IMAGES_FILE")

  if [[ ( "$DRY_RUN" == "true" || "$PREFLIGHT_ONLY" == "true" ) && "$IMAGE_ENTRY_TYPE" == "object" ]]; then
    SOURCE_IMAGE_REQUIRED_ENV_VAR=$(image_entry_field "$IMAGE_KEY" "$IMAGES_FILE" "env_var")
    SOURCE_IMAGE_DESCRIPTION=$(image_entry_field "$IMAGE_KEY" "$IMAGES_FILE" "description")
    SOURCE_IMAGE_URI="${!SOURCE_IMAGE_REQUIRED_ENV_VAR:-}"

    if [[ -z "$SOURCE_IMAGE_URI" ]]; then
      SOURCE_IMAGE_RESOLUTION_STATUS="missing-env"
      SOURCE_IMAGE_RAW_DISPLAY="<set ${SOURCE_IMAGE_REQUIRED_ENV_VAR}>"
    else
      SOURCE_IMAGE_RAW_DISPLAY="$SOURCE_IMAGE_URI"
    fi
  else
    SOURCE_IMAGE_URI=$(resolve_image_source "$IMAGE_KEY" "$IMAGES_FILE")
    SOURCE_IMAGE_RAW_DISPLAY="$SOURCE_IMAGE_URI"
  fi
fi

if [[ "$OS_TYPE" == "RHEL" || "$OS_TYPE" == "Red Hat Enterprise Linux (RHEL)" ]]; then
  PREFETCH_SOURCE_IMAGE=true
fi

if [[ "$DRY_RUN" == "true" || "$PREFLIGHT_ONLY" == "true" ]]; then
  if [[ -n "$SOURCE_IMAGE_NAME_OVERRIDE" ]]; then
    PACKER_SOURCE_IMAGE_NAME="$SOURCE_IMAGE_NAME_OVERRIDE"
    PACKER_SOURCE_IMAGE_URI="<not used>"
    PACKER_SOURCE_IMAGE_PATH="<not used>"
    SOURCE_IMAGE_RUNTIME_ACTION="reuse the existing Prism image by name"
  elif [[ "$SOURCE_IMAGE_RESOLUTION_STATUS" == "missing-env" ]]; then
    PACKER_SOURCE_IMAGE_URI="<unresolved until ${SOURCE_IMAGE_REQUIRED_ENV_VAR} is set>"
    PACKER_SOURCE_IMAGE_NAME="<not used>"
    PACKER_SOURCE_IMAGE_PATH="<not used>"
    SOURCE_IMAGE_RUNTIME_ACTION="source image env var required before live build"
  elif [[ "$SOURCE_IMAGE_URI" =~ ^file:// ]]; then
    PACKER_SOURCE_IMAGE_NAME="<not used>"
    PACKER_SOURCE_IMAGE_URI="<not used>"
    PACKER_SOURCE_IMAGE_PATH="${SOURCE_IMAGE_URI#file://}"
    SOURCE_IMAGE_RUNTIME_ACTION="use the provided local file path via source_image_path"
  elif [[ -n "$SOURCE_IMAGE_URI" && -f "$SOURCE_IMAGE_URI" ]]; then
    PACKER_SOURCE_IMAGE_NAME="<not used>"
    PACKER_SOURCE_IMAGE_URI="<not used>"
    PACKER_SOURCE_IMAGE_PATH="${SOURCE_IMAGE_URI}"
    SOURCE_IMAGE_RUNTIME_ACTION="use the provided local file path via source_image_path"
  elif [[ "$PREFETCH_SOURCE_IMAGE" == "true" ]]; then
    PACKER_SOURCE_IMAGE_NAME="<not used>"
    PACKER_SOURCE_IMAGE_URI="<not used>"
    PACKER_SOURCE_IMAGE_PATH="<temporary local file created at runtime>"
    SOURCE_IMAGE_RUNTIME_ACTION="download the remote source image to a local temp file and pass it via source_image_path"
  else
    PACKER_SOURCE_IMAGE_NAME="<not used>"
    PACKER_SOURCE_IMAGE_URI="$SOURCE_IMAGE_URI"
    PACKER_SOURCE_IMAGE_PATH="<not used>"
    SOURCE_IMAGE_RUNTIME_ACTION="pass the resolved remote URI directly to Packer"
  fi
else
  if [[ -n "$SOURCE_IMAGE_NAME_OVERRIDE" ]]; then
    PACKER_SOURCE_IMAGE_NAME="$SOURCE_IMAGE_NAME_OVERRIDE"
    PACKER_SOURCE_IMAGE_URI=""
    PACKER_SOURCE_IMAGE_PATH=""
  else
    PACKER_SOURCE_IMAGE_NAME=""
    if [[ "$STAGE_SOURCE" == "true" && "$SOURCE_IMAGE_URI" =~ ^https?:// ]]; then
      PACKER_SOURCE_IMAGE_URI="$SOURCE_IMAGE_URI"
      PACKER_SOURCE_IMAGE_PATH=""
    else
      SOURCE_IMAGE_URI=$(materialize_source_image "$SOURCE_IMAGE_URI" "$PREFETCH_SOURCE_IMAGE")
      if [[ "$SOURCE_IMAGE_URI" =~ ^file:// ]]; then
        PACKER_SOURCE_IMAGE_PATH="${SOURCE_IMAGE_URI#file://}"
        PACKER_SOURCE_IMAGE_URI=""
      else
        PACKER_SOURCE_IMAGE_URI="$SOURCE_IMAGE_URI"
        PACKER_SOURCE_IMAGE_PATH=""
      fi
    fi
  fi
  SOURCE_IMAGE_RUNTIME_ACTION="resolved for live build"
  ANSIBLE_VARS_FILE=$(write_ansible_vars_file "$ANSIBLE_VARS_JSON")
fi

# --- Generate Image Name ---
TIMESTAMP=$(date +%Y%m%d%H%M%S)
IMAGE_NAME="ndb-${NDB_VERSION}-${DB_TYPE}-${DB_VERSION}-${OS_TYPE}-${OS_VERSION}-${TIMESTAMP}"
VM_NAME_BASE=$(slugify "${NDB_VERSION}-${DB_TYPE}-${DB_VERSION}-${OS_TYPE}-${OS_VERSION}")
VM_NAME="ndb-${VM_NAME_BASE:0:40}-${TIMESTAMP}"

if [[ "$WRITE_MANIFEST" == "true" && "$DRY_RUN" != "true" && "$PREFLIGHT_ONLY" != "true" ]]; then
  MANIFEST_FILE="${SCRIPT_DIR}/manifests/${IMAGE_NAME}.json"
  "$MANIFEST_HELPER" init \
    --file "$MANIFEST_FILE" \
    --image-name "$IMAGE_NAME" \
    --ndb-version "$NDB_VERSION" \
    --db-type "$DB_TYPE" \
    --db-version "$DB_VERSION" \
    --os-type "$OS_TYPE" \
    --os-version "$OS_VERSION" \
    --provisioning-role "$PROVISIONING_ROLE" \
    --matrix-row-json "$CONFIG"
fi

if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
  if [[ "$SOURCE_IMAGE_RESOLUTION_STATUS" == "missing-env" ]]; then
    echo "Error: source image environment variable is missing: ${SOURCE_IMAGE_REQUIRED_ENV_VAR}" >&2
    print_dry_run_summary
    exit 1
  fi

  PREFLIGHT_STATUS=0
  source_image_preflight \
    --source-image-name "$PACKER_SOURCE_IMAGE_NAME" \
    --source-image-uri "$PACKER_SOURCE_IMAGE_URI" \
    --source-image-path "$PACKER_SOURCE_IMAGE_PATH" \
    --cluster-name "$PKR_VAR_cluster_name" \
    --subnet-name "$PKR_VAR_subnet_name" || PREFLIGHT_STATUS=$?
  print_dry_run_summary
  exit "$PREFLIGHT_STATUS"
fi

if [[ "$STAGE_SOURCE" == "true" && -z "$PACKER_SOURCE_IMAGE_NAME" && "$PACKER_SOURCE_IMAGE_URI" =~ ^https?:// ]]; then
  CLUSTER_UUID=$(prism_cluster_uuid_by_name "$PKR_VAR_cluster_name")
  if [[ -z "$CLUSTER_UUID" ]]; then
    echo "Error: could not find Prism cluster ${PKR_VAR_cluster_name}" >&2
    exit 1
  fi

  PACKER_SOURCE_IMAGE_NAME=$(source_image_stage_remote_uri "$PACKER_SOURCE_IMAGE_URI" "$CLUSTER_UUID")
  PACKER_SOURCE_IMAGE_URI=""
  PACKER_SOURCE_IMAGE_PATH=""
  SOURCE_IMAGE_RUNTIME_ACTION="staged remote source image in Prism before live build"
fi

if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".source_image.name" --value "$PACKER_SOURCE_IMAGE_NAME"
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".source_image.uri" --value "$PACKER_SOURCE_IMAGE_URI"
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".source_image.path" --value "$PACKER_SOURCE_IMAGE_PATH"
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".source_image.runtime_action" --value "$SOURCE_IMAGE_RUNTIME_ACTION"
fi

if [[ "$DRY_RUN" == "true" ]]; then
  print_dry_run_summary
  exit 0
fi

# --- Run Packer ---
echo "Starting Packer build for image: ${IMAGE_NAME}"

PACKER_CMD=(packer build)
if [[ "$DEBUG" == "true" ]]; then
  PACKER_CMD+=( -debug )
fi

PACKER_STARTED_EPOCH=$(date +%s)
if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".packer.started_at" --value "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
fi

"${PACKER_CMD[@]}" \
  -var "ansible_site_playbook=${ANSIBLE_SITE_PLAYBOOK}" \
  -var "ansible_config_path=${ANSIBLE_CONFIG_PATH}" \
  -var "ansible_extra_vars_file=${ANSIBLE_VARS_FILE}" \
  -var "ndb_version=${NDB_VERSION}" \
  -var "os_type=${OS_TYPE}" \
  -var "os_version=${OS_VERSION}" \
  -var "db_type=${DB_TYPE}" \
  -var "db_version=${DB_VERSION}" \
  -var "patroni_version=${PATRONI_VERSION}" \
  -var "etcd_version=${ETCD_VERSION}" \
  -var "source_image_name=${PACKER_SOURCE_IMAGE_NAME}" \
  -var "source_image_uri=${PACKER_SOURCE_IMAGE_URI}" \
  -var "source_image_path=${PACKER_SOURCE_IMAGE_PATH}" \
  -var "image_name=${IMAGE_NAME}" \
  -var "vm_name=${VM_NAME}" \
  -var "ssh_public_key=$(cat "$PUBLIC_KEY_PATH")" \
  packer/

PACKER_FINISHED_EPOCH=$(date +%s)
if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".packer.finished_at" --value "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  "$MANIFEST_HELPER" set-json --file "$MANIFEST_FILE" --key ".packer.duration_seconds" --json-value "$((PACKER_FINISHED_EPOCH - PACKER_STARTED_EPOCH))"
fi
ARTIFACT_IMAGE_UUID=$(prism_image_uuid_by_name "$IMAGE_NAME" || true)

if [[ "$VALIDATE_ARTIFACT" == "true" ]]; then
  ARTIFACT_RESULT_FILE=$(mktemp -t ndb-artifact-validation.XXXXXX.json)
  TEMP_FILES+=("$ARTIFACT_RESULT_FILE")
  ARTIFACT_VALIDATE_CMD=(
    "$SCRIPT_DIR/scripts/artifact_validate.sh"
    --image-name "$IMAGE_NAME"
    --ndb-version "$NDB_VERSION"
    --db-version "$DB_VERSION"
    --db-type "$DB_TYPE"
    --extensions "$POSTGRES_EXTENSIONS_JSON"
    --result-file "$ARTIFACT_RESULT_FILE"
  )
  if [[ "$DEBUG" == "true" ]]; then
    ARTIFACT_VALIDATE_CMD+=(--keep-on-failure)
  fi

  if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
    "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".validation.artifact" --value "running"
  fi

  ARTIFACT_VALIDATION_STATUS=0
  "${ARTIFACT_VALIDATE_CMD[@]}" || ARTIFACT_VALIDATION_STATUS=$?

  if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" && -f "$ARTIFACT_RESULT_FILE" ]]; then
    "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".validation.artifact" --value "$(jq -r '.status' "$ARTIFACT_RESULT_FILE")"
    "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".validation.artifact_vm_name" --value "$(jq -r '.vm_name' "$ARTIFACT_RESULT_FILE")"
    "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".validation.artifact_vm_uuid" --value "$(jq -r '.vm_uuid' "$ARTIFACT_RESULT_FILE")"
    "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".cleanup.artifact_validation_vm" --value "$(jq -r '.cleanup_status' "$ARTIFACT_RESULT_FILE")"
  fi
  if [[ "$ARTIFACT_VALIDATION_STATUS" -ne 0 ]]; then
    exit "$ARTIFACT_VALIDATION_STATUS"
  fi
elif [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".validation.artifact" --value "not-requested"
fi

if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
  "$MANIFEST_HELPER" finalize --file "$MANIFEST_FILE" --status success --artifact-image-uuid "$ARTIFACT_IMAGE_UUID"
  MANIFEST_FINALIZED=true
fi
