#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

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
  command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is required to run the build wizard."
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

join_json_array() {
  jq -r 'if type == "array" and length > 0 then join(", ") else "" end'
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
      jq -c '.[] | select((.provisioning_role // "") == "postgresql" and ((.extensions // []) | length) > 0)' "$matrix_file"
      ;;
    pgsql_no_extensions)
      jq -c '.[] | select((.provisioning_role // "") == "postgresql" and ((.extensions // []) | length) == 0)' "$matrix_file"
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
      + (if ((.extensions // []) | length) > 0 then
          " (extensions: \((.extensions // []) | join(", ")))"
        else
          " (no extensions)"
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
  local role db_type os_type os_version db_version extensions reason deployments
  role=$(jq -r '.provisioning_role' <<<"$row_json")
  db_type=$(jq -r '.db_type' <<<"$row_json")
  os_type=$(jq -r '.os_type' <<<"$row_json")
  os_version=$(jq -r '.os_version' <<<"$row_json")
  db_version=$(jq -r '.db_version' <<<"$row_json")

  printf '\nSelected image:\n'
  printf '  Database: %s %s\n' "$db_type" "$db_version"
  printf '  OS: %s %s\n' "$os_type" "$os_version"

  if [[ "$role" == "postgresql" ]]; then
    extensions=$(jq -c '.extensions // []' <<<"$row_json" | join_json_array)
    if [[ -n "$extensions" ]]; then
      printf '  Extensions: %s\n' "$extensions"
    else
      printf '  Extensions: No PostgreSQL extensions requested.\n'
      reason=$(jq -r '.extensions_empty_reason // ""' <<<"$row_json")
      if [[ -n "$reason" ]]; then
        printf '  Extension reason: %s\n' "$reason"
      else
        printf '  Extension warning: missing extensions_empty_reason; run scripts/matrix_validate.sh ndb/*/matrix.json before building.\n'
      fi
    fi
  elif [[ "$role" == "mongodb" ]]; then
    deployments=$(jq -c '.deployment // []' <<<"$row_json" | join_json_array)
    printf '  MongoDB deployments: %s\n' "$deployments"
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

append_source_args() {
  local action_arg=$1
  local choice value

  if [[ "$action_arg" == "--stage-source" ]]; then
    return 0
  fi

  choice=$(prompt_menu "Source image strategy" \
    "Use matrix default" \
    "Use existing Prism image name" \
    "Use existing Prism image UUID")
  case "$choice" in
    0)
      return 0
      ;;
    1)
      value=$(prompt_value "Existing Prism image name")
      COMMAND_ARGS+=("--source-image-name" "$value")
      ;;
    2)
      value=$(prompt_value "Existing Prism image UUID")
      COMMAND_ARGS+=("--source-image-uuid" "$value")
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

declare -a COMMAND_ARGS=()

main() {
  local versions=() version_choice ndb_version matrix_file
  local filter_choice filter_name rows=() row_labels=() row_choice row_json
  local action_choice action_arg db_type os_type os_version db_version final_choice
  local version row

  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  if (( $# > 0 )); then
    fail "The build wizard does not accept command-line options yet. Run it interactively."
  fi

  require_command jq
  cd "$ROOT_DIR"

  while IFS= read -r version; do
    versions+=("$version")
  done < <(load_ndb_versions)
  version_choice=$(prompt_menu "NDB version" "${versions[@]}")
  ndb_version="${versions[$version_choice]}"
  matrix_file="$ROOT_DIR/ndb/$ndb_version/matrix.json"
  [[ -f "$matrix_file" ]] || fail "Matrix file not found: $matrix_file"

  filter_choice=$(prompt_menu "Rows to show" \
    "All buildable rows" \
    "PostgreSQL rows with extensions" \
    "PostgreSQL rows without extensions" \
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
  if [[ "$action_arg" != "build" ]]; then
    COMMAND_ARGS+=("$action_arg")
  else
    if choose_yes_no "Run in-guest validation?"; then
      COMMAND_ARGS+=("--validate")
    fi
    if choose_yes_no "Run saved-artifact validation?"; then
      COMMAND_ARGS+=("--validate-artifact")
    fi
    if choose_yes_no "Write manifest?"; then
      COMMAND_ARGS+=("--manifest")
    fi
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

  append_source_args "$action_arg"
  append_customization_args
  print_source_image_warning "$row_json"

  printf '\nCommand preview:\n'
  print_row_details "$row_json"
  if [[ "$action_arg" == "build" ]]; then
    printf '  Action: build\n'
  else
    printf '  Action: %s\n' "$action_arg"
  fi
  printf '\n'
  print_command "${COMMAND_ARGS[@]}"

  final_choice=$(prompt_menu "Next step" "Print command only" "Run command now")
  if [[ "$final_choice" == "1" ]]; then
    printf '\nRunning command...\n'
    "${COMMAND_ARGS[@]}"
  fi
}

main "$@"
