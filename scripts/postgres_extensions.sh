#!/usr/bin/env bash

POSTGRES_INSTALLABLE_EXTENSIONS=(
  pg_cron
  pglogical
  pg_partman
  pg_stat_statements
  pgvector
  pgaudit
  postgis
  set_user
  timescaledb
)

postgres_installable_extensions_json() {
  printf '%s\n' "${POSTGRES_INSTALLABLE_EXTENSIONS[@]}" | jq -R . | jq -s .
}

postgres_extension_normalize_name() {
  local value=$1
  value=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/^ +//; s/ +$//; s/[[:space:]]+/_/g')
  case "$value" in
    pg_vector) printf 'pgvector\n' ;;
    pg_logical) printf 'pglogical\n' ;;
    timescaledb) printf 'timescaledb\n' ;;
    pgaudit) printf 'pgaudit\n' ;;
    postgis) printf 'postgis\n' ;;
    pg_lo) printf 'lo\n' ;;
    *) printf '%s\n' "$value" ;;
  esac
}

postgres_extensions_selection_to_json() {
  local selection=${1:-}
  local value normalized
  local values=()
  local normalized_values=()

  if [[ -z "$selection" || "$selection" == "none" ]]; then
    printf '[]\n'
    return 0
  fi
  if [[ "$selection" == "all-qualified" ]]; then
    echo "Error: all-qualified requires postgres_extensions_resolve_selection_json." >&2
    return 1
  fi

  IFS=',' read -r -a values <<<"$selection"
  for value in "${values[@]}"; do
    normalized=$(postgres_extension_normalize_name "$value")
    [[ -n "$normalized" ]] && normalized_values+=("$normalized")
  done

  if (( ${#normalized_values[@]} == 0 )); then
    printf '[]\n'
    return 0
  fi
  printf '%s\n' "${normalized_values[@]}" | jq -R . | jq -s 'unique'
}

postgres_extensions_unknown_json() {
  local selected_json=$1
  local installable_json
  installable_json=$(postgres_installable_extensions_json)
  jq -nc \
    --argjson selected "$selected_json" \
    --argjson installable "$installable_json" \
    '$selected | map(select(. as $name | $installable | index($name) | not))'
}

postgres_extensions_not_qualified_json() {
  local selected_json=$1
  local qualified_json=${2:-[]}
  jq -nc \
    --argjson selected "$selected_json" \
    --argjson qualified "$qualified_json" \
    '$selected | map(select(. as $name | $qualified | index($name) | not))'
}

postgres_extensions_resolve_selection_json() {
  local selection=${1:-none}
  local qualified_json=${2:-[]}
  local installable_json

  if [[ "$selection" != "all-qualified" ]]; then
    postgres_extensions_selection_to_json "$selection"
    return
  fi

  installable_json=$(postgres_installable_extensions_json)
  jq -nc \
    --argjson qualified "$qualified_json" \
    --argjson installable "$installable_json" \
    '$qualified | map(select(. as $name | $installable | index($name))) | unique'
}

postgres_extensions_all_qualified_skipped_json() {
  local qualified_json=${1:-[]}
  local installable_json
  installable_json=$(postgres_installable_extensions_json)
  jq -nc \
    --argjson qualified "$qualified_json" \
    --argjson installable "$installable_json" \
    '$qualified | map(select(. as $name | $installable | index($name) | not)) | unique'
}

postgres_extensions_json_to_csv() {
  jq -r 'if type == "array" and length > 0 then join(",") else "" end'
}
