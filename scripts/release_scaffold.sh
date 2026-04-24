#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

usage() {
  cat <<'EOF'
Usage: scripts/release_scaffold.sh NEW_VERSION --from OLD_VERSION [--dry-run]

Creates ndb/NEW_VERSION and ansible/NEW_VERSION from an existing release.

Examples:
  scripts/release_scaffold.sh 2.11 --from 2.10
  scripts/release_scaffold.sh 2.11 --from 2.10 --dry-run
EOF
}

require_option_value() {
  local option=$1
  local remaining_args=$2
  if (( remaining_args < 2 )); then
    printf 'Error: %s requires a value.\n' "$option" >&2
    usage >&2
    exit 1
  fi
}

require_command() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    printf 'Error: required commands not found: %s\n' "${missing[*]}" >&2
    exit 1
  fi
}

validate_version() {
  local label=$1
  local version=$2
  if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
    printf 'Error: %s must look like 2.10 or 2.11, got: %s\n' "$label" "$version" >&2
    exit 1
  fi
}

NEW_VERSION=""
FROM_VERSION=""
DRY_RUN=false
STAGING_DIR=""
SCAFFOLD_COMPLETE=false
PUBLISHED_TARGETS=()

cleanup_staging() {
  local target
  if [[ "$SCAFFOLD_COMPLETE" != "true" && (( ${#PUBLISHED_TARGETS[@]} > 0 )) ]]; then
    for target in "${PUBLISHED_TARGETS[@]}"; do
      rm -rf "$target"
    done
  fi
  if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
    rm -rf "$STAGING_DIR"
  fi
}
trap cleanup_staging EXIT

if [[ $# -gt 0 && "$1" != -* ]]; then
  NEW_VERSION=$1
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)
      require_option_value "$1" "$#"
      FROM_VERSION=$2
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown parameter: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z "$NEW_VERSION" || -z "$FROM_VERSION" ]]; then
  usage >&2
  exit 1
fi

validate_version "NEW_VERSION" "$NEW_VERSION"
validate_version "OLD_VERSION" "$FROM_VERSION"

cd "$ROOT_DIR"

for source_path in "ndb/${FROM_VERSION}" "ansible/${FROM_VERSION}"; do
  if [[ ! -d "$source_path" ]]; then
    printf 'Error: source path missing: %s\n' "$source_path" >&2
    exit 1
  fi
done

for target_path in "ndb/${NEW_VERSION}" "ansible/${NEW_VERSION}"; do
  if [[ -e "$target_path" ]]; then
    printf 'Error: target already exists: %s\n' "$target_path" >&2
    exit 1
  fi
done

if [[ "$DRY_RUN" == "true" ]]; then
  printf 'Would copy ndb/%s to ndb/%s\n' "$FROM_VERSION" "$NEW_VERSION"
  printf 'Would copy ansible/%s to ansible/%s\n' "$FROM_VERSION" "$NEW_VERSION"
  printf 'Would rewrite ndb_version values in ndb/%s/matrix.json\n' "$NEW_VERSION"
  printf 'Would create ndb/%s/REVIEW.md\n' "$NEW_VERSION"
  exit 0
fi

require_command jq ansible-playbook cp

STAGING_DIR=$(mktemp -d ".release-scaffold-${NEW_VERSION}.XXXXXX")
mkdir -p "$STAGING_DIR/ndb" "$STAGING_DIR/ansible"

cp -R "ndb/${FROM_VERSION}" "$STAGING_DIR/ndb/${NEW_VERSION}"
cp -R "ansible/${FROM_VERSION}" "$STAGING_DIR/ansible/${NEW_VERSION}"

if [[ -f "$STAGING_DIR/ndb/${NEW_VERSION}/matrix.json" ]]; then
  tmp=$(mktemp)
  jq --arg version "$NEW_VERSION" 'map(.ndb_version = $version)' "$STAGING_DIR/ndb/${NEW_VERSION}/matrix.json" > "$tmp"
  mv "$tmp" "$STAGING_DIR/ndb/${NEW_VERSION}/matrix.json"
fi

cat > "$STAGING_DIR/ndb/${NEW_VERSION}/REVIEW.md" <<EOF
# NDB ${NEW_VERSION} Release Review

Review these items before building this release:

- Confirm every PostgreSQL row against the NDB ${NEW_VERSION} release notes.
- Confirm OS versions and source image entries exist in images.json.
- Confirm PostgreSQL extensions are available for each OS and DB version.
- Confirm HA metadata versions for Patroni and etcd.
- Run scripts/matrix_validate.sh ndb/${NEW_VERSION}/matrix.json.
- Run Ansible syntax check for ansible/${NEW_VERSION}/playbooks/site.yml.
EOF

scripts/matrix_validate.sh "$STAGING_DIR/ndb/${NEW_VERSION}/matrix.json"
ANSIBLE_CONFIG="$STAGING_DIR/ansible/${NEW_VERSION}/ansible.cfg" ansible-playbook -i "$STAGING_DIR/ansible/${NEW_VERSION}/inventory/hosts" "$STAGING_DIR/ansible/${NEW_VERSION}/playbooks/site.yml" --syntax-check

PUBLISHED_TARGETS+=("ndb/${NEW_VERSION}")
mv "$STAGING_DIR/ndb/${NEW_VERSION}" "ndb/${NEW_VERSION}"
PUBLISHED_TARGETS+=("ansible/${NEW_VERSION}")
mv "$STAGING_DIR/ansible/${NEW_VERSION}" "ansible/${NEW_VERSION}"
SCAFFOLD_COMPLETE=true

printf 'Created ndb/%s and ansible/%s\n' "$NEW_VERSION" "$NEW_VERSION"
