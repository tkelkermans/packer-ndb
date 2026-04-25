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
    def deployment_key($entry):
      if ($entry.deployment | type) == "array" then
        ($entry.deployment | map(tostring) | sort | join("+"))
      else
        ""
      end;
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
              select(($entry.provisioning_role // null) == "mongodb" and ($entry.db_type // null) != "mongodb")
              | "\(ctx($idx; $entry)): provisioning_role '\''mongodb'\'' requires db_type '\''mongodb'\''"
            ),
            (
              select(($entry.provisioning_role // null) == "mongodb" and ($entry.os_version | type) == "string" and ($entry.os_version | test("\\(")))
              | "\(ctx($idx; $entry)): os_version must not encode MongoDB topology; use deployment metadata instead"
            ),
            (
              select(($entry.provisioning_role // null) == "mongodb" and (($entry.mongodb_edition // "") | IN("community", "enterprise") | not))
              | "\(ctx($idx; $entry)): buildable MongoDB rows require mongodb_edition community or enterprise"
            ),
            (
              select(($entry.db_type // null) == "mongodb" and (($entry.deployment | type) != "array" or ($entry.deployment | length) == 0))
              | "\(ctx($idx; $entry)): MongoDB rows require deployment as a non-empty list"
            ),
            (
              select(($entry.db_type // null) == "mongodb" and ($entry.deployment | type) == "array")
              | select(any($entry.deployment[]; (. | IN("single-instance", "replica-set", "sharded-cluster") | not)))
              | "\(ctx($idx; $entry)): MongoDB deployment values must be single-instance, replica-set, or sharded-cluster"
            ),
            (
              select(($entry.db_type // null) == "mongodb" and ($entry.deployment | type) == "array" and (($entry.deployment | length) != ($entry.deployment | unique | length)))
              | "\(ctx($idx; $entry)): MongoDB deployment values must not contain duplicates"
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
              select(
                ($entry.db_type // null) == "pgsql"
                and ($entry.provisioning_role // null) == "postgresql"
                and (
                  (($entry | has("extensions")) | not)
                  or ($entry.extensions == null)
                  or (($entry.extensions | type) == "array" and ($entry.extensions | length) == 0)
                )
                and (($entry.extensions_empty_reason // "") | nonempty_string | not)
              )
              | "\(ctx($idx; $entry)): buildable PostgreSQL rows with no extensions must include non-empty '\''extensions_empty_reason'\''"
            ),
            (
              select(($entry | has("extensions_empty_reason")) and (($entry.extensions_empty_reason | nonempty_string) | not))
              | "\(ctx($idx; $entry)): '\''extensions_empty_reason'\'' must be a non-empty string when present"
            ),
            (
              select(($entry.extensions | type) == "array" and ($entry.extensions | length) > 0 and ($entry | has("extensions_empty_reason")))
              | "\(ctx($idx; $entry)): omit '\''extensions_empty_reason'\'' when '\''extensions'\'' contains values"
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
        | group_by([
            .db_type,
            .os_type,
            .os_version,
            .db_version,
            (.mongodb_edition // ""),
            deployment_key(.),
            (.provisioning_role // "")
          ])[]
        | select(length > 1)
        | .[0] as $entry
        | "\(ctx("duplicate"; $entry)): duplicate combination [db_type=\($entry.db_type | tojson), os_type=\($entry.os_type | tojson), os_version=\($entry.os_version | tojson), db_version=\($entry.db_version | tojson), mongodb_edition=\(($entry.mongodb_edition // "") | tojson), deployment=\(deployment_key($entry) | tojson), provisioning_role=\(($entry.provisioning_role // "") | tojson)]"
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
