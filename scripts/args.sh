#!/usr/bin/env bash
# Shared CLI argument-parsing helpers. Source this file; do not execute it.

# Fail fast when a value-taking option is the last argument, instead of
# consuming the next flag or crashing on an unbound $2 under set -u.
require_option_value() {
  local option=$1
  local remaining_args=$2
  if (( remaining_args < 2 )); then
    printf 'Error: %s requires a value.\n' "$option" >&2
    exit 1
  fi
}

# [[ "$value" -gt 0 ]] silently arithmetic-coerces non-numeric strings to 0,
# so options like --limit must validate their value explicitly.
require_numeric_option_value() {
  local option=$1
  local value=$2
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    printf 'Error: %s requires a non-negative integer value, got: %s\n' "$option" "$value" >&2
    exit 1
  fi
}
