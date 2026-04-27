#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/postgres_extensions.sh
source "$ROOT_DIR/scripts/postgres_extensions.sh"

REQUIRED_LIVE_COMMANDS=(packer ansible-playbook curl ssh base64)
LIVE_ENV_KEYS=(
  PKR_VAR_pc_username
  PKR_VAR_pc_password
  PKR_VAR_pc_ip
  PKR_VAR_cluster_name
  PKR_VAR_subnet_name
)

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/build_wizard.sh

Guides you through one image selection, prints the generated ./build.sh command,
and optionally runs it.
EOF
}

require_command() {
  local command_name=$1
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing %s.\n' "$command_name" >&2
    printf 'Install %s, then rerun scripts/build_wizard.sh.\n' "$command_name" >&2
    exit 1
  fi
}

shell_quote() {
  local value=${1-}
  local escaped
  if [[ "$value" =~ ^[A-Za-z0-9_./:=@+-]+$ ]]; then
    printf '%s' "$value"
  else
    escaped=${value//\'/\'\\\'\'}
    printf "'%s'" "$escaped"
  fi
}

print_command() {
  local rendered="" arg
  for arg in "$@"; do
    if [[ -n "$rendered" ]]; then
      rendered+=" "
    fi
    rendered+="$(shell_quote "$arg")"
  done
  printf '%s\n' "$rendered"
}

prompt_menu() {
  local title=$1
  shift
  local options=("$@")
  local choice index

  if (( ${#options[@]} == 0 )); then
    fail "No options available for ${title}."
  fi

  printf '\n%s\n' "$title" >&2
  for index in "${!options[@]}"; do
    printf '  %d. %s\n' "$((index + 1))" "${options[$index]}" >&2
  done

  while true; do
    printf 'Choose [1-%d]: ' "${#options[@]}" >&2
    IFS= read -r choice || fail "No selection provided for ${title}."
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      printf '%s\n' "$((choice - 1))"
      return 0
    fi
    printf 'Invalid selection. Please try again.\n' >&2
  done
}

prompt_value() {
  local prompt=$1
  local value
  while true; do
    printf '%s: ' "$prompt" >&2
    IFS= read -r value || fail "No value provided for ${prompt}."
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
    printf 'Value cannot be empty.\n' >&2
  done
}

command_status() {
  local command_name=$1
  if command -v "$command_name" >/dev/null 2>&1; then
    printf 'present'
  else
    printf 'missing'
  fi
}

env_status() {
  local key=$1
  if [[ -n "${!key:-}" ]]; then
    printf 'present'
  else
    printf 'missing'
  fi
}

env_vars_missing() {
  local key
  for key in "${LIVE_ENV_KEYS[@]}"; do
    [[ -n "${!key:-}" ]] || return 0
  done
  return 1
}

live_commands_missing() {
  local command_name
  for command_name in "${REQUIRED_LIVE_COMMANDS[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 || return 0
  done
  return 1
}

ssh_keypair_missing() {
  [[ -f "$ROOT_DIR/packer/id_rsa" && -f "$ROOT_DIR/packer/id_rsa.pub" ]] && return 1
  return 0
}

print_readiness_summary() {
  local command_name key

  printf '\nFirst build readiness check\n'
  printf 'Local tools:\n'
  printf '  jq: present\n'
  printf '  cksum: present\n'
  for command_name in "${REQUIRED_LIVE_COMMANDS[@]}"; do
    printf '  %s: %s\n' "$command_name" "$(command_status "$command_name")"
  done
  printf '  op: %s (optional, only needed for 1Password-managed .env files)\n' "$(command_status op)"

  printf '\nSSH key:\n'
  if [[ -f "$ROOT_DIR/packer/id_rsa.pub" ]]; then
    printf '  packer/id_rsa.pub: present\n'
  else
    printf '  packer/id_rsa.pub: missing - required for live builds and artifact validation\n'
  fi
  if [[ -f "$ROOT_DIR/packer/id_rsa" ]]; then
    printf '  packer/id_rsa: present\n'
  else
    printf '  packer/id_rsa: missing - required for live builds and artifact validation\n'
  fi

  printf '\nEnvironment:\n'
  if [[ -f "$ROOT_DIR/.env" ]]; then
    printf '  .env: present\n'
  else
    printf '  .env: missing\n'
  fi
  for key in "${LIVE_ENV_KEYS[@]}"; do
    printf '  %s: %s\n' "$key" "$(env_status "$key")"
  done
  printf '  Tip: if 1Password manages .env, run: op run --env-file .env -- scripts/build_wizard.sh\n'
}

copy_env_example() {
  [[ -f "$ROOT_DIR/.env.example" ]] || fail ".env.example is missing; cannot create .env."
  if [[ -f "$ROOT_DIR/.env" ]]; then
    printf '.env already exists; leaving it unchanged.\n'
    return 0
  fi
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
  printf 'Created .env from .env.example. Edit it or run the wizard through op before live builds.\n'
}

create_ssh_keypair() {
  if [[ -f "$ROOT_DIR/packer/id_rsa" || -f "$ROOT_DIR/packer/id_rsa.pub" ]]; then
    fail "One packer SSH key file already exists. Refusing to overwrite partial keypair."
  fi
  mkdir -p "$ROOT_DIR/packer"
  ssh-keygen -t rsa -b 4096 -C "packer@nutanix" -f "$ROOT_DIR/packer/id_rsa" -N ""
  printf 'Created packer/id_rsa and packer/id_rsa.pub.\n'
}

run_packer_init() {
  packer init packer/
  printf 'Packer plugins initialized for packer/.\n'
}

run_first_build_assistant() {
  local options=() actions=() choice

  while true; do
    print_readiness_summary
    options=("Continue to image selection")
    actions=("continue")

    if ssh_keypair_missing && command -v ssh-keygen >/dev/null 2>&1; then
      options+=("Create missing packer SSH keypair")
      actions+=("create_ssh_keypair")
    fi
    if [[ ! -f "$ROOT_DIR/.env" && -f "$ROOT_DIR/.env.example" ]]; then
      options+=("Create .env from .env.example")
      actions+=("copy_env")
    fi
    if command -v packer >/dev/null 2>&1; then
      options+=("Run packer init packer/")
      actions+=("packer_init")
    fi

    choice=$(prompt_menu "Readiness actions" "${options[@]}")
    case "${actions[$choice]}" in
      continue)
        return 0
        ;;
      create_ssh_keypair)
        create_ssh_keypair
        ;;
      copy_env)
        copy_env_example
        ;;
      packer_init)
        run_packer_init
        ;;
    esac
  done
}

action_uses_live_prism() {
  local action_arg=$1
  [[ "$action_arg" == "--preflight" || "$action_arg" == "--stage-source" || "$action_arg" == "build" ]]
}

action_requires_ssh_keypair() {
  local action_arg=$1
  [[ "$action_arg" == "build" ]]
}

assert_run_now_prerequisites() {
  local action_arg=$1
  local missing=false

  if [[ "$action_arg" == "--dry-run" ]]; then
    return 0
  fi

  if action_uses_live_prism "$action_arg" && live_commands_missing; then
    printf 'Cannot run this live action yet. Missing one or more live-build commands:\n' >&2
    local command_name
    for command_name in "${REQUIRED_LIVE_COMMANDS[@]}"; do
      if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '  - %s\n' "$command_name" >&2
      fi
    done
    missing=true
  fi

  if action_uses_live_prism "$action_arg" && env_vars_missing; then
    printf 'Cannot run this live action yet. Missing one or more Prism variables:\n' >&2
    local key
    for key in "${LIVE_ENV_KEYS[@]}"; do
      if [[ -z "${!key:-}" ]]; then
        printf '  - %s\n' "$key" >&2
      fi
    done
    printf 'Edit .env and source it, or run: op run --env-file .env -- scripts/build_wizard.sh\n' >&2
    missing=true
  fi

  if action_requires_ssh_keypair "$action_arg" && ssh_keypair_missing; then
    printf 'Cannot run a live build yet. Missing packer SSH keypair.\n' >&2
    printf 'Create it from the readiness menu or run:\n' >&2
    printf '  ssh-keygen -t rsa -b 4096 -C "packer@nutanix" -f packer/id_rsa -N ""\n' >&2
    missing=true
  fi

  [[ "$missing" == "false" ]] || exit 1
}

join_json_array() {
  jq -r 'if type == "array" and length > 0 then join(", ") else "" end'
}

mongodb_deployments_human() {
  jq -r '
    if type != "array" or length == 0 then
      "none"
    else
      map(
        if . == "single-instance" then "single instance"
        elif . == "replica-set" then "replica set smoke test"
        elif . == "sharded-cluster" then "sharded cluster smoke test"
        else .
        end
      ) | join(", ")
    end
  '
}

load_ndb_versions() {
  find "$ROOT_DIR/ndb" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

load_buildable_rows() {
  local matrix_file=$1
  local filter_name=$2
  case "$filter_name" in
    all)
      jq -c '.[] | select((.provisioning_role // "") as $role | ($role == "postgresql" or $role == "mongodb"))' "$matrix_file"
      ;;
    pgsql_extensions)
      jq -c '.[] | select((.provisioning_role // "") == "postgresql" and ((.qualified_extensions // []) | length) > 0)' "$matrix_file"
      ;;
    pgsql_no_extensions)
      jq -c '.[] | select((.provisioning_role // "") == "postgresql" and ((.qualified_extensions // []) | length) == 0)' "$matrix_file"
      ;;
    mongodb)
      jq -c '.[] | select((.provisioning_role // "") == "mongodb")' "$matrix_file"
      ;;
    *)
      fail "Unknown row filter: $filter_name"
      ;;
  esac
}

row_label() {
  local row_json=$1
  jq -r '
    if .provisioning_role == "postgresql" then
      "PostgreSQL \(.db_version) on \(.os_type) \(.os_version)"
      + (if ((.qualified_extensions // []) | length) > 0 then
          " (qualified extensions: \((.qualified_extensions // []) | join(", ")))"
        else
          " (no qualified extensions)"
        end)
    elif .provisioning_role == "mongodb" then
      "MongoDB \(.db_version) on \(.os_type) \(.os_version)"
    else
      "\(.engine) \(.db_version) on \(.os_type) \(.os_version)"
    end
  ' <<<"$row_json"
}

print_row_details() {
  local row_json=$1
  local role db_type os_type os_version db_version extensions reason deployments edition
  role=$(jq -r '.provisioning_role' <<<"$row_json")
  db_type=$(jq -r '.db_type' <<<"$row_json")
  os_type=$(jq -r '.os_type' <<<"$row_json")
  os_version=$(jq -r '.os_version' <<<"$row_json")
  db_version=$(jq -r '.db_version' <<<"$row_json")

  printf '\nSelected image:\n'
  printf '  Database: %s %s\n' "$db_type" "$db_version"
  printf '  OS: %s %s\n' "$os_type" "$os_version"

  if [[ "$role" == "postgresql" ]]; then
    extensions=$(jq -c '.qualified_extensions // []' <<<"$row_json" | join_json_array)
    if [[ -n "$extensions" ]]; then
      printf '  Qualified extensions: %s\n' "$extensions"
    else
      printf '  Qualified extensions: none listed for this row.\n'
      reason=$(jq -r '.qualified_extensions_empty_reason // ""' <<<"$row_json")
      if [[ -n "$reason" ]]; then
        printf '  Qualified extension reason: %s\n' "$reason"
      else
        printf '  Extension warning: missing qualified_extensions_empty_reason; run scripts/matrix_validate.sh ndb/*/matrix.json before building.\n'
      fi
    fi
  elif [[ "$role" == "mongodb" ]]; then
    edition=$(jq -r '.mongodb_edition // "community"' <<<"$row_json")
    deployments=$(jq -c '.deployment // []' <<<"$row_json" | mongodb_deployments_human)
    printf '  MongoDB edition: %s\n' "$edition"
    printf '  MongoDB validation shape: %s\n' "$deployments"
  fi
}

print_selected_recipe() {
  local row_json=$1
  local action_arg=$2
  local source_summary=$3
  local extensions_summary=${4:-none}
  local image_suffix_summary=${5:-none}
  local role db_type os_type os_version db_version ndb_version validation_summary manifest_summary edition deployments

  role=$(jq -r '.provisioning_role' <<<"$row_json")
  db_type=$(jq -r '.db_type' <<<"$row_json")
  os_type=$(jq -r '.os_type' <<<"$row_json")
  os_version=$(jq -r '.os_version' <<<"$row_json")
  db_version=$(jq -r '.db_version' <<<"$row_json")
  ndb_version=$(jq -r '.ndb_version' <<<"$row_json")

  if [[ " ${COMMAND_ARGS[*]} " == *" --validate "* && " ${COMMAND_ARGS[*]} " == *" --validate-artifact "* ]]; then
    validation_summary="in-guest + saved artifact"
  elif [[ " ${COMMAND_ARGS[*]} " == *" --validate "* ]]; then
    validation_summary="in-guest only"
  elif [[ " ${COMMAND_ARGS[*]} " == *" --validate-artifact "* ]]; then
    validation_summary="saved artifact only"
  else
    validation_summary="not requested"
  fi

  if [[ " ${COMMAND_ARGS[*]} " == *" --manifest "* ]]; then
    manifest_summary="yes"
  else
    manifest_summary="no"
  fi

  printf '\nSelected image recipe:\n'
  printf '  Database: %s %s\n' "$db_type" "$db_version"
  printf '  OS: %s %s\n' "$os_type" "$os_version"
  printf '  NDB: %s\n' "$ndb_version"
  printf '  Source image: %s\n' "$source_summary"
  printf '  Action: %s\n' "$action_arg"
  printf '  Validation: %s\n' "$validation_summary"
  printf '  Manifest: %s\n' "$manifest_summary"

  if [[ "$role" == "postgresql" ]]; then
    printf '  PostgreSQL extensions: %s\n' "$extensions_summary"
    printf '  Image variant suffix: %s\n' "$image_suffix_summary"
  elif [[ "$role" == "mongodb" ]]; then
    edition=$(jq -r '.mongodb_edition // "community"' <<<"$row_json")
    deployments=$(jq -c '.deployment // []' <<<"$row_json" | mongodb_deployments_human)
    printf '  MongoDB edition: %s\n' "$edition"
    printf '  MongoDB validation shape: %s\n' "$deployments"
  fi
}

source_image_key() {
  local os_type=$1
  local os_version=$2

  case "$os_type" in
    "Red Hat Enterprise Linux (RHEL)"|"RHEL")
      printf 'rhel-%s\n' "$os_version"
      ;;
    "Rocky Linux")
      printf 'rocky-linux-%s\n' "$os_version"
      ;;
    "Ubuntu Linux")
      printf 'ubuntu-linux-%s\n' "$os_version"
      ;;
    *)
      printf '%s-%s\n' \
        "$(printf '%s' "$os_type" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')" \
        "$os_version"
      ;;
  esac
}

print_source_image_warning() {
  local row_json=$1
  local os_type os_version key env_var description
  os_type=$(jq -r '.os_type' <<<"$row_json")
  os_version=$(jq -r '.os_version' <<<"$row_json")
  key=$(source_image_key "$os_type" "$os_version")

  if [[ ! -f "$ROOT_DIR/images.json" ]]; then
    return 0
  fi

  env_var=$(jq -r --arg key "$key" 'if (.[$key] | type) == "object" then .[$key].env_var // "" else "" end' "$ROOT_DIR/images.json")
  if [[ -n "$env_var" && -z "${!env_var:-}" ]]; then
    description=$(jq -r --arg key "$key" 'if (.[$key] | type) == "object" then .[$key].description // "" else "" end' "$ROOT_DIR/images.json")
    printf '\nWarning: source image variable %s is not set.\n' "$env_var"
    if [[ -n "$description" ]]; then
      printf '  %s\n' "$description"
    fi
  fi
}

load_profile_names() {
  local profile
  for profile in "$ROOT_DIR"/customizations/profiles/*.yml; do
    [[ -e "$profile" ]] || continue
    basename "$profile" .yml
  done | sort
}

choose_yes_no() {
  local title=$1
  local choice
  choice=$(prompt_menu "$title" "Yes" "No")
  [[ "$choice" == "0" ]]
}

prompt_multi_select() {
  local title=$1
  shift
  local options=("$@")
  local value token index valid
  local selected=()

  printf '\n%s\n' "$title" >&2
  printf '  0. None\n' >&2
  for index in "${!options[@]}"; do
    printf '  %d. %s\n' "$((index + 1))" "${options[$index]}" >&2
  done

  while true; do
    printf 'Choose numbers separated by spaces [0-%d]: ' "${#options[@]}" >&2
    IFS= read -r value || fail "No selection provided for ${title}."
    if [[ -z "$value" || "$value" == "0" ]]; then
      return 0
    fi

    selected=()
    valid=true
    for token in $value; do
      if [[ "$token" =~ ^[0-9]+$ ]] && (( token >= 1 && token <= ${#options[@]} )); then
        selected+=("${options[$((token - 1))]%% *}")
      else
        valid=false
      fi
    done
    if [[ "$valid" == "true" ]]; then
      printf '%s\n' "${selected[@]}" | awk '!seen[$0]++'
      return 0
    fi
    printf 'Invalid selection. Please try again.\n' >&2
  done
}

append_postgres_extension_args() {
  local row_json=$1
  local qualified_json installable_json qualified_installable_json advanced_json selected_json selected_csv warnings_json
  local resolved_for_suffix_json image_suffix
  local options=() extension

  POSTGRES_EXTENSIONS_SUMMARY="none"
  POSTGRES_IMAGE_SUFFIX_SUMMARY="none"
  qualified_json=$(jq -c '.qualified_extensions // []' <<<"$row_json")
  installable_json=$(postgres_installable_extensions_json)
  qualified_installable_json=$(jq -nc --argjson qualified "$qualified_json" --argjson installable "$installable_json" '$qualified | map(select(. as $name | $installable | index($name)))')
  advanced_json=$(jq -nc --argjson qualified "$qualified_json" --argjson installable "$installable_json" '$installable | map(select(. as $name | $qualified | index($name) | not))')

  printf '\nPostgreSQL extensions are optional. Default: none.\n'
  printf 'Qualified extensions: %s\n' "$(jq -r 'if length > 0 then join(", ") else "none" end' <<<"$qualified_json")"

  while IFS= read -r extension; do
    options+=("${extension} (qualified)")
  done < <(jq -r '.[]' <<<"$qualified_installable_json")
  while IFS= read -r extension; do
    options+=("${extension} (advanced: not release-note-qualified for this row)")
  done < <(jq -r '.[]' <<<"$advanced_json")

  if (( ${#options[@]} == 0 )); then
    printf 'No installable PostgreSQL extensions are available for selection.\n'
    return 0
  fi

  selected_json=$(prompt_multi_select "PostgreSQL extensions to install" "${options[@]}" | jq -R . | jq -s 'map(select(length > 0))')
  selected_csv=$(postgres_extensions_json_to_csv <<<"$selected_json")
  if [[ -n "$selected_csv" ]]; then
    COMMAND_ARGS+=("--extensions" "$selected_csv")
    resolved_for_suffix_json=$(postgres_extensions_resolve_selection_json "$selected_csv" "$qualified_json")
    image_suffix=$(postgres_extensions_image_name_suffix_json "$resolved_for_suffix_json")
    warnings_json=$(postgres_extensions_not_qualified_json "$selected_json" "$qualified_json")
    if [[ "$(jq 'length' <<<"$warnings_json")" -gt 0 ]]; then
      while IFS= read -r extension; do
        printf 'Warning: Extension %s is installable by this tool, but is not release-note-qualified for this matrix row.\n' "$extension"
      done < <(jq -r '.[]' <<<"$warnings_json")
    fi
    printf 'Selected extensions: %s\n' "$(jq -r 'join(", ")' <<<"$selected_json")"
    printf 'Image name suffix: %s\n' "$image_suffix"
    POSTGRES_EXTENSIONS_SUMMARY="$(jq -r 'join(", ")' <<<"$selected_json")"
    POSTGRES_IMAGE_SUFFIX_SUMMARY="$image_suffix"
  else
    printf 'Selected extensions: none\n'
    printf 'Image name suffix: none\n'
    POSTGRES_EXTENSIONS_SUMMARY="none"
    POSTGRES_IMAGE_SUFFIX_SUMMARY="none"
  fi
}

append_source_args() {
  local action_arg=$1
  local choice value

  SOURCE_SUMMARY="matrix default"
  if [[ "$action_arg" == "--stage-source" ]]; then
    return 0
  fi

  choice=$(prompt_menu "Source image strategy" \
    "Use matrix default" \
    "Use existing Prism image name" \
    "Use existing Prism image UUID")
  case "$choice" in
    0)
      SOURCE_SUMMARY="matrix default"
      return 0
      ;;
    1)
      value=$(prompt_value "Existing Prism image name")
      COMMAND_ARGS+=("--source-image-name" "$value")
      SOURCE_SUMMARY="existing Prism image name"
      ;;
    2)
      value=$(prompt_value "Existing Prism image UUID")
      COMMAND_ARGS+=("--source-image-uuid" "$value")
      SOURCE_SUMMARY="existing Prism image UUID"
      ;;
  esac
}

append_customization_args() {
  local choice profile_choice profile_path profile
  local profiles=()

  while IFS= read -r profile; do
    profiles+=("$profile")
  done < <(load_profile_names)

  choice=$(prompt_menu "Customization" \
    "No command-line customization profile" \
    "Force no customizations (--no-customizations)" \
    "Use a repository profile" \
    "Use a manual profile path")

  case "$choice" in
    0)
      return 0
      ;;
    1)
      COMMAND_ARGS+=("--no-customizations")
      ;;
    2)
      if (( ${#profiles[@]} == 0 )); then
        fail "No profiles found under customizations/profiles."
      fi
      profile_choice=$(prompt_menu "Customization profiles" "${profiles[@]}")
      COMMAND_ARGS+=("--customization-profile" "${profiles[$profile_choice]}")
      ;;
    3)
      profile_path=$(prompt_value "Customization profile path")
      COMMAND_ARGS+=("--customization-profile" "$profile_path")
      ;;
  esac
}

append_build_safety_args() {
  local choice
  choice=$(prompt_menu "Production safety checks" \
    "Use recommended validation and manifest (--validate --validate-artifact --manifest)" \
    "Choose validation flags one by one" \
    "No validation flags")

  case "$choice" in
    0)
      COMMAND_ARGS+=("--validate" "--validate-artifact" "--manifest")
      ;;
    1)
      if choose_yes_no "Run in-guest validation?"; then
        COMMAND_ARGS+=("--validate")
      fi
      if choose_yes_no "Run saved-artifact validation?"; then
        COMMAND_ARGS+=("--validate-artifact")
      fi
      if choose_yes_no "Write manifest?"; then
        COMMAND_ARGS+=("--manifest")
      fi
      ;;
    2)
      return 0
      ;;
  esac
}

declare -a COMMAND_ARGS=()
SOURCE_SUMMARY="matrix default"
POSTGRES_EXTENSIONS_SUMMARY="none"
POSTGRES_IMAGE_SUFFIX_SUMMARY="none"

main() {
  local versions=() version_choice ndb_version matrix_file
  local filter_choice filter_name rows=() row_labels=() row_choice row_json
  local action_choice action_arg db_type os_type os_version db_version final_choice source_summary extensions_summary image_suffix_summary
  local version row

  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  if (( $# > 0 )); then
    fail "The build wizard does not accept command-line options yet. Run it interactively."
  fi

  require_command jq
  require_command cksum
  cd "$ROOT_DIR"
  run_first_build_assistant

  while IFS= read -r version; do
    versions+=("$version")
  done < <(load_ndb_versions)
  version_choice=$(prompt_menu "NDB version" "${versions[@]}")
  ndb_version="${versions[$version_choice]}"
  matrix_file="$ROOT_DIR/ndb/$ndb_version/matrix.json"
  [[ -f "$matrix_file" ]] || fail "Matrix file not found: $matrix_file"

  filter_choice=$(prompt_menu "Rows to show" \
    "All buildable rows" \
    "PostgreSQL rows with qualified extensions" \
    "PostgreSQL rows without qualified extensions" \
    "MongoDB rows")
  case "$filter_choice" in
    0) filter_name="all" ;;
    1) filter_name="pgsql_extensions" ;;
    2) filter_name="pgsql_no_extensions" ;;
    3) filter_name="mongodb" ;;
  esac

  while IFS= read -r row; do
    rows+=("$row")
    row_labels+=("$(row_label "$row")")
  done < <(load_buildable_rows "$matrix_file" "$filter_name")
  if (( ${#rows[@]} == 0 )); then
    fail "No buildable rows match the selected filter."
  fi

  row_choice=$(prompt_menu "Buildable image rows" "${row_labels[@]}")
  row_json="${rows[$row_choice]}"
  print_row_details "$row_json"

  action_choice=$(prompt_menu "Action" \
    "Dry run (safe preview)" \
    "Preflight only" \
    "Stage source image" \
    "Build image")
  case "$action_choice" in
    0) action_arg="--dry-run" ;;
    1) action_arg="--preflight" ;;
    2) action_arg="--stage-source" ;;
    3) action_arg="build" ;;
  esac

  COMMAND_ARGS=("./build.sh" "--ci")
  source_summary="matrix default"
  extensions_summary="none"
  image_suffix_summary="none"
  if [[ "$action_arg" != "build" ]]; then
    COMMAND_ARGS+=("$action_arg")
  else
    append_build_safety_args
  fi

  db_type=$(jq -r '.db_type' <<<"$row_json")
  os_type=$(jq -r '.os_type' <<<"$row_json")
  os_version=$(jq -r '.os_version' <<<"$row_json")
  db_version=$(jq -r '.db_version' <<<"$row_json")

  COMMAND_ARGS+=(
    "--ndb-version" "$ndb_version"
    "--db-type" "$db_type"
    "--os" "$os_type"
    "--os-version" "$os_version"
    "--db-version" "$db_version"
  )

  if [[ "$(jq -r '.provisioning_role' <<<"$row_json")" == "postgresql" ]]; then
    append_postgres_extension_args "$row_json"
    extensions_summary="$POSTGRES_EXTENSIONS_SUMMARY"
    image_suffix_summary="$POSTGRES_IMAGE_SUFFIX_SUMMARY"
  fi

  append_source_args "$action_arg"
  source_summary="$SOURCE_SUMMARY"
  append_customization_args
  print_source_image_warning "$row_json"

  printf '\nCommand preview:\n'
  print_selected_recipe "$row_json" "$action_arg" "$source_summary" "$extensions_summary" "$image_suffix_summary"
  printf '\n'
  print_command "${COMMAND_ARGS[@]}"

  final_choice=$(prompt_menu "Next step" "Print command only" "Run command now")
  if [[ "$final_choice" == "1" ]]; then
    assert_run_now_prerequisites "$action_arg"
    printf '\nRunning command...\n'
    "${COMMAND_ARGS[@]}"
  fi
}

main "$@"
