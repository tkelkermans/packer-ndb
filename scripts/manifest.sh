#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/manifest.sh init --file FILE --image-name NAME --ndb-version VERSION --db-type TYPE --db-version VERSION --os-type NAME --os-version VERSION --provisioning-role ROLE --matrix-row-json JSON
  scripts/manifest.sh set --file FILE --key JQ_PATH --value VALUE
  scripts/manifest.sh set-json --file FILE --key JQ_PATH --json-value JSON
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
        file=$2
        shift
        ;;
      --image-name)
        image_name=$2
        shift
        ;;
      --ndb-version)
        ndb_version=$2
        shift
        ;;
      --db-type)
        db_type=$2
        shift
        ;;
      --db-version)
        db_version=$2
        shift
        ;;
      --os-type)
        os_type=$2
        shift
        ;;
      --os-version)
        os_version=$2
        shift
        ;;
      --provisioning-role)
        provisioning_role=$2
        shift
        ;;
      --matrix-row-json)
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
        name: null,
        uri: null,
        path: null,
        runtime_action: null
      },
      packer: {
        started_at: null,
        finished_at: null,
        duration_seconds: null
      },
      artifact: {
        image_uuid: null
      },
      validation: {
        in_guest: "not-requested",
        artifact: "not-requested",
        artifact_vm_name: null,
        artifact_vm_uuid: null
      },
      cleanup: {},
      git: {
        commit: $git_commit,
        dirty: $git_dirty
      }
    }' > "$file"
}

cmd_set() {
  local file="" path="" value=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)
        file=$2
        shift
        ;;
      --key|--path|--field)
        path=$2
        shift
        ;;
      --value)
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
        file=$2
        shift
        ;;
      --key|--path|--field)
        path=$2
        shift
        ;;
      --json-value|--value-json|--json)
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
        file=$2
        shift
        ;;
      --status)
        status=$2
        shift
        ;;
      --artifact-image-uuid)
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
