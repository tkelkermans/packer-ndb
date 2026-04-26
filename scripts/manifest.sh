#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/manifest.sh init --file FILE --image-name NAME --ndb-version VERSION --db-type TYPE --db-version VERSION --os-type NAME --os-version VERSION --provisioning-role ROLE --matrix-row-json JSON
  scripts/manifest.sh set --file FILE --key JQ_PATH --value VALUE
  scripts/manifest.sh set-json --file FILE --key JQ_PATH --json-value JSON
  scripts/manifest.sh record-artifact-validation --file FILE --result-file FILE --exit-status STATUS
  scripts/manifest.sh finalize --file FILE --status STATUS [--artifact-image-uuid UUID]
EOF
}

require_jq_path() {
  local path=$1
  if [[ ! "$path" =~ ^\.[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$ ]]; then
    echo "Error: only simple jq object paths are supported: ${path}" >&2
    exit 1
  fi
}

require_option_value() {
  local option=$1
  local remaining_args=$2
  if (( remaining_args < 2 )); then
    echo "Error: ${option} requires a value." >&2
    usage >&2
    exit 1
  fi
}

write_json_atomically() {
  local file=$1
  local tmp_file
  tmp_file=$(mktemp "${file}.XXXXXX")
  cat > "$tmp_file"
  mv "$tmp_file" "$file"
}

git_commit() {
  git rev-parse HEAD 2>/dev/null || printf ''
}

git_dirty() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'false'
    return
  fi

  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

cmd_init() {
  local file="" image_name="" ndb_version="" db_type="" db_version=""
  local os_type="" os_version="" provisioning_role="" matrix_row_json=""
  local started_at commit dirty

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)
        require_option_value "$1" "$#"
        file=$2
        shift
        ;;
      --image-name)
        require_option_value "$1" "$#"
        image_name=$2
        shift
        ;;
      --ndb-version)
        require_option_value "$1" "$#"
        ndb_version=$2
        shift
        ;;
      --db-type)
        require_option_value "$1" "$#"
        db_type=$2
        shift
        ;;
      --db-version)
        require_option_value "$1" "$#"
        db_version=$2
        shift
        ;;
      --os-type)
        require_option_value "$1" "$#"
        os_type=$2
        shift
        ;;
      --os-version)
        require_option_value "$1" "$#"
        os_version=$2
        shift
        ;;
      --provisioning-role)
        require_option_value "$1" "$#"
        provisioning_role=$2
        shift
        ;;
      --matrix-row-json)
        require_option_value "$1" "$#"
        matrix_row_json=$2
        shift
        ;;
      *)
        echo "Unknown init parameter: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done

  if [[ -z "$file" || -z "$image_name" || -z "$ndb_version" || -z "$db_type" || -z "$db_version" || -z "$os_type" || -z "$os_version" || -z "$provisioning_role" || -z "$matrix_row_json" ]]; then
    echo "Error: init requires all manifest selection fields." >&2
    usage >&2
    exit 1
  fi

  mkdir -p "$(dirname "$file")"
  started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  commit=$(git_commit)
  dirty=$(git_dirty)

  jq -n \
    --arg image_name "$image_name" \
    --arg status "running" \
    --arg started_at "$started_at" \
    --arg ndb_version "$ndb_version" \
    --arg db_type "$db_type" \
    --arg db_version "$db_version" \
    --arg os_type "$os_type" \
    --arg os_version "$os_version" \
    --arg provisioning_role "$provisioning_role" \
    --argjson matrix_row "$matrix_row_json" \
    --arg git_commit "$commit" \
    --argjson git_dirty "$dirty" \
    '{
      image_name: $image_name,
      status: $status,
      started_at: $started_at,
      finished_at: null,
      selection: {
        ndb_version: $ndb_version,
        db_type: $db_type,
        db_version: $db_version,
        os_type: $os_type,
        os_version: $os_version,
        provisioning_role: $provisioning_role
      },
      matrix_row: $matrix_row,
      source_image: {
        mode: null,
        name: null,
        uri: null,
        path: null,
        uuid: null,
        runtime_action: null
      },
      packer: {
        started_at: null,
        finished_at: null,
        duration_seconds: null
      },
      artifact: {
        image_name: null,
        image_uuid: null
      },
      validation: {
        in_guest: "not-requested",
        artifact: "not-requested",
        artifact_vm_name: null,
        artifact_vm_uuid: null
      },
      customization: {
        enabled: false,
        profile: null,
        profile_file: null,
        phases: {},
        validation: "not-requested"
      },
      cleanup: {},
      git: {
        commit: $git_commit,
        dirty: $git_dirty
      }
    }' | write_json_atomically "$file"
}

cmd_set() {
  local file="" path="" value=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)
        require_option_value "$1" "$#"
        file=$2
        shift
        ;;
      --key|--path|--field)
        require_option_value "$1" "$#"
        path=$2
        shift
        ;;
      --value)
        require_option_value "$1" "$#"
        value=$2
        shift
        ;;
      *)
        echo "Unknown set parameter: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done

  if [[ -z "$file" || -z "$path" ]]; then
    echo "Error: set requires --file and --key." >&2
    usage >&2
    exit 1
  fi

  require_jq_path "$path"
  jq --arg value "$value" "${path} = \$value" "$file" | write_json_atomically "$file"
}

cmd_set_json() {
  local file="" path="" value_json=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)
        require_option_value "$1" "$#"
        file=$2
        shift
        ;;
      --key|--path|--field)
        require_option_value "$1" "$#"
        path=$2
        shift
        ;;
      --json-value|--value-json|--json)
        require_option_value "$1" "$#"
        value_json=$2
        shift
        ;;
      *)
        echo "Unknown set-json parameter: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done

  if [[ -z "$file" || -z "$path" || -z "$value_json" ]]; then
    echo "Error: set-json requires --file, --key, and --json-value." >&2
    usage >&2
    exit 1
  fi

  require_jq_path "$path"
  jq --argjson value "$value_json" "${path} = \$value" "$file" | write_json_atomically "$file"
}

cmd_finalize() {
  local file="" status="" artifact_image_uuid="" finished_at

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)
        require_option_value "$1" "$#"
        file=$2
        shift
        ;;
      --status)
        require_option_value "$1" "$#"
        status=$2
        shift
        ;;
      --artifact-image-uuid)
        require_option_value "$1" "$#"
        artifact_image_uuid=$2
        shift
        ;;
      *)
        echo "Unknown finalize parameter: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done

  if [[ -z "$file" || -z "$status" ]]; then
    echo "Error: finalize requires --file and --status." >&2
    usage >&2
    exit 1
  fi

  finished_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq \
    --arg status "$status" \
    --arg finished_at "$finished_at" \
    --arg artifact_image_uuid "$artifact_image_uuid" \
    '.status = $status
      | .finished_at = $finished_at
      | if $artifact_image_uuid != "" then .artifact.image_uuid = $artifact_image_uuid else . end' \
    "$file" | write_json_atomically "$file"
}

cmd_record_artifact_validation() {
  local file="" result_file="" exit_status=""
  local artifact_status artifact_vm_name artifact_vm_uuid cleanup_status
  local result_is_valid=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)
        require_option_value "$1" "$#"
        file=$2
        shift
        ;;
      --result-file)
        require_option_value "$1" "$#"
        result_file=$2
        shift
        ;;
      --exit-status)
        require_option_value "$1" "$#"
        exit_status=$2
        shift
        ;;
      *)
        echo "Unknown record-artifact-validation parameter: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done

  if [[ -z "$file" || -z "$result_file" || -z "$exit_status" ]]; then
    echo "Error: record-artifact-validation requires --file, --result-file, and --exit-status." >&2
    usage >&2
    exit 1
  fi

  if [[ -s "$result_file" ]] && jq -e 'type == "object"' "$result_file" >/dev/null 2>&1; then
    result_is_valid=true
  fi

  if [[ "$result_is_valid" == "true" ]]; then
    artifact_status=$(jq -r '.status // empty' "$result_file")
    artifact_vm_name=$(jq -r '.artifact_vm_name // .vm_name // ""' "$result_file")
    artifact_vm_uuid=$(jq -r '.artifact_vm_uuid // .vm_uuid // ""' "$result_file")
    cleanup_status=$(jq -r '.cleanup.artifact_validation_vm // .cleanup_status // ""' "$result_file")
    if [[ -z "$artifact_status" ]]; then
      if [[ "$exit_status" -eq 0 ]]; then
        artifact_status="passed"
      else
        artifact_status="failed"
      fi
    fi
  else
    artifact_status="failed"
    artifact_vm_name=""
    artifact_vm_uuid=""
    cleanup_status="result-unavailable"
  fi

  jq \
    --arg artifact_status "$artifact_status" \
    --arg artifact_vm_name "$artifact_vm_name" \
    --arg artifact_vm_uuid "$artifact_vm_uuid" \
    --arg cleanup_status "$cleanup_status" \
    '.validation.artifact = $artifact_status
      | .validation.artifact_vm_name = $artifact_vm_name
      | .validation.artifact_vm_uuid = $artifact_vm_uuid
      | .cleanup.artifact_validation_vm = $cleanup_status' \
    "$file" | write_json_atomically "$file"

  if [[ "$result_is_valid" != "true" && "$exit_status" -eq 0 ]]; then
    echo "Error: artifact validation reported success but did not write valid result JSON: ${result_file}" >&2
    return 1
  fi
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

command=$1
shift

case "$command" in
  init)
    cmd_init "$@"
    ;;
  set)
    cmd_set "$@"
    ;;
  set-json)
    cmd_set_json "$@"
    ;;
  record-artifact-validation)
    cmd_record_artifact_validation "$@"
    ;;
  finalize)
    cmd_finalize "$@"
    ;;
  -h|--help)
    usage
    ;;
  *)
    echo "Unknown command: ${command}" >&2
    usage >&2
    exit 1
    ;;
esac
