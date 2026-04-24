#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required to validate matrix files." >&2
  exit 1
fi

if (( $# > 0 )); then
  MATRIX_FILES=("$@")
else
  MATRIX_FILES=(ndb/*/matrix.json)
fi

if (( ${#MATRIX_FILES[@]} == 0 )) || [[ ! -e "${MATRIX_FILES[0]}" ]]; then
  echo "Error: No matrix files found under ndb/." >&2
  exit 1
fi

validate_matrix_file() {
  local matrix_file=$1
  local expected_version
  local errors

  if [[ ! -f "$matrix_file" ]]; then
    echo "Matrix validation failed (${matrix_file}):" >&2
    echo "  - Matrix file not found: ${matrix_file}" >&2
    return 1
  fi

  expected_version=$(basename "$(dirname "$matrix_file")")

  if ! errors=$(jq -r --arg expected "$expected_version" '
    def trim_string: gsub("^\\s+|\\s+$"; "");
    def nonempty_string: type == "string" and (trim_string | length > 0);
    def display($value): if $value == null then "None" else ($value | tostring) end;
    def ctx($idx; $entry):
      "[\($idx)] \(display($entry.db_type // null)) | \(display($entry.os_type // null)) \(display($entry.os_version // null)) | \(display($entry.db_version // null))";

    if type != "array" then
      "Matrix must be a JSON array (got \(type))"
    else
      (
        to_entries[]
        | .key as $idx
        | .value as $entry
        | if ($entry | type) != "object" then
            "[\($idx)] entry must be an object (got \($entry | type))"
          else
            (
              ["ndb_version", "engine", "db_type", "os_type", "os_version", "db_version", "provisioning_role"][]
              as $field
              | select((($entry | has($field)) | not) or (($entry[$field] | type) != "string") or (($entry[$field] | trim_string) == ""))
              | "\(ctx($idx; $entry)): missing, non-string, or empty field '\''\($field)'\''"
            ),
            (
              select($expected != "" and ($entry.ndb_version // null) != $expected)
              | "\(ctx($idx; $entry)): ndb_version \($entry.ndb_version | tojson) does not match path version \($expected | tojson)"
            ),
            (
              select(($entry.db_version | type == "string") and ($entry.db_version | contains("/")))
              | "\(ctx($idx; $entry)): db_version contains '\''/'\'', split versions into distinct entries (\($entry.db_version | tojson))"
            ),
            (
              select(($entry.provisioning_role // null) == "postgresql" and ($entry.db_type // null) != "pgsql")
              | "\(ctx($idx; $entry)): provisioning_role '\''postgresql'\'' requires db_type '\''pgsql'\''"
            ),
            (
              select(($entry | has("extensions")) and ($entry.extensions != null) and (($entry.extensions | type) != "array"))
              | "\(ctx($idx; $entry)): '\''extensions'\'' must be a list or omitted"
            ),
            (
              select(($entry.extensions | type) == "array" and any($entry.extensions[]; (nonempty_string | not)))
              | "\(ctx($idx; $entry)): '\''extensions'\'' must only contain non-empty strings"
            ),
            (
              select(($entry | has("ha_components")) and ($entry.ha_components != null) and (($entry.ha_components | type) != "object"))
              | "\(ctx($idx; $entry)): '\''ha_components'\'' must be an object when present"
            ),
            (
              select(($entry.ha_components | type) == "object")
              | $entry.ha_components
              | to_entries[]
              | select((.key | nonempty_string | not) or ((.value | type) != "array") or any(.value[]; (nonempty_string | not)))
              | "\(ctx($idx; $entry)): ha_components['\''\(.key)'\''] must be a list of non-empty strings"
            )
          end
      ),
      (
        [.[] | select(type == "object")]
        | group_by([.db_type, .os_type, .os_version, .db_version])[]
        | select(length > 1)
        | .[0] as $entry
        | "\(ctx("duplicate"; $entry)): duplicate combination [\($entry.db_type | tojson), \($entry.os_type | tojson), \($entry.os_version | tojson), \($entry.db_version | tojson)]"
      )
    end
  ' "$matrix_file" 2>&1); then
    echo "Matrix validation failed (${matrix_file}):" >&2
    printf '%s\n' "$errors" | sed 's/^/  - /' >&2
    return 1
  fi

  if [[ -n "$errors" ]]; then
    echo "Matrix validation failed (${matrix_file}):" >&2
    printf '%s\n' "$errors" | sed 's/^/  - /' >&2
    return 1
  fi

  echo "Matrix validation succeeded (${matrix_file})"
}

has_errors=false
for matrix_file in "${MATRIX_FILES[@]}"; do
  if ! validate_matrix_file "$matrix_file"; then
    has_errors=true
  fi
done

if [[ "$has_errors" == "true" ]]; then
  exit 1
fi
