#!/bin/bash

# Master build script for NDB Packer images

set -e

if [[ -z "$PKR_VAR_pc_username" || -z "$PKR_VAR_pc_password" || -z "$PKR_VAR_pc_ip" || -z "$PKR_VAR_cluster_name" || -z "$PKR_VAR_subnet_name" ]]; then
  echo "Error: Required environment variables are not set."
  echo "Please set PKR_VAR_pc_username, PKR_VAR_pc_password, PKR_VAR_pc_ip, PKR_VAR_cluster_name, and PKR_VAR_subnet_name."
  exit 1
fi

DEBUG=false
if [[ "$1" == "--debug" ]]; then
  export PACKER_LOG=1
  DEBUG=true
  shift
fi

# --- Helper Functions ---


function select_from_list() {
  local item_type=$1
  shift
  local items=("$@")
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

# --- Main Logic ---
if [[ "$1" == "--ci" ]]; then
  # --- CI/CD Mode ---
  shift
  while [[ "$#" -gt 0 ]]; do
    case $1 in
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
      *)
        echo "Unknown parameter: $1"
        exit 1
    esac
    shift
  done

  ANSIBLE_SITE_PLAYBOOK="ansible/${NDB_VERSION}/playbooks/site.yml"
  ANSIBLE_CONFIG_PATH="ANSIBLE_CONFIG=ansible/${NDB_VERSION}/ansible.cfg"

  MATRIX_FILE="ndb/${NDB_VERSION}/matrix.json"
  if [[ ! -f "$MATRIX_FILE" ]]; then
    echo "Error: matrix.json not found for NDB version ${NDB_VERSION}. Please create it manually."
    exit 1
  fi

  CONFIG=$(jq -c --arg os "$OS_TYPE" --arg os_ver "$OS_VERSION" --arg db_ver "$DB_VERSION" \
    '.[] | select(.os_type == $os and .os_version == $os_ver and .db_version == $db_ver)' \
    "$MATRIX_FILE")

  if [[ -z "$CONFIG" ]]; then
    echo "Error: No matching configuration found in matrix.json for the specified parameters."
    exit 1
  fi

else
  # --- Interactive Mode ---
  NDB_VERSIONS=($(ls -d ndb/*/ | xargs -n 1 basename))
  NDB_VERSION=$(select_from_list "NDB Version" "${NDB_VERSIONS[@]}")

  ANSIBLE_SITE_PLAYBOOK="ansible/${NDB_VERSION}/playbooks/site.yml"
  ANSIBLE_CONFIG_PATH="ANSIBLE_CONFIG=ansible/${NDB_VERSION}/ansible.cfg"

  MATRIX_FILE="ndb/${NDB_VERSION}/matrix.json"
  if [[ ! -f "$MATRIX_FILE" ]]; then
    echo "Error: matrix.json not found for NDB version ${NDB_VERSION}. Please create it manually."
    exit 1
  fi

  OS_TYPES=()
  while IFS= read -r line; do
    OS_TYPES+=("$line")
  done < <(jq -r '.[].os_type' "$MATRIX_FILE" | sort -u)
  OS_TYPE=$(select_from_list "OS" "${OS_TYPES[@]}")

  OS_VERSIONS=()
  while IFS= read -r line; do
    OS_VERSIONS+=("$line")
  done < <(jq -r --arg os "$OS_TYPE" '.[] | select(.os_type == $os) | .os_version' "$MATRIX_FILE" | sort -u)
  OS_VERSION=$(select_from_list "OS Version" "${OS_VERSIONS[@]}")

  DB_VERSIONS=()
  while IFS= read -r line; do
    DB_VERSIONS+=("$line")
  done < <(jq -r --arg os "$OS_TYPE" --arg os_ver "$OS_VERSION" '.[] | select(.os_type == $os and .os_version == $os_ver) | .db_version' "$MATRIX_FILE" | sort -u)
  DB_VERSION=$(select_from_list "DB Version" "${DB_VERSIONS[@]}")

  cat <<EOF > ansible/vars.json
{
  "db_version": "${DB_VERSION}",
  "ndb_version": "${NDB_VERSION}"
}
EOF

  ANSIBLE_SITE_PLAYBOOK="ansible/${NDB_VERSION}/playbooks/site.yml"
  ANSIBLE_CONFIG_PATH="ANSIBLE_CONFIG=ansible/${NDB_VERSION}/ansible.cfg"

  CONFIG=$(jq -c --arg os "$OS_TYPE" --arg os_ver "$OS_VERSION" --arg db_ver "$DB_VERSION" \
    '.[] | select(.os_type == $os and .os_version == $os_ver and .db_version == $db_ver)' \
    "$MATRIX_FILE")
fi

# --- Extract variables from the selected configuration ---
PATRONI_VERSION=$(echo "$CONFIG" | jq -r '.patroni_version')
ETCD_VERSION=$(echo "$CONFIG" | jq -r '.etcd_version')
DB_TYPE=$(echo "$CONFIG" | jq -r '.db_type')

# --- Get Source Image URI ---
IMAGE_KEY=$(echo "${OS_TYPE}-${OS_VERSION}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
SOURCE_IMAGE_URI=$(jq -r --arg key "$IMAGE_KEY" '.[$key]' images.json)

if [[ -z "$SOURCE_IMAGE_URI" || "$SOURCE_IMAGE_URI" == "null" ]]; then
  echo "Error: No source image URI found for ${OS_TYPE} ${OS_VERSION} in images.json"
  exit 1
fi

# --- Generate Image Name ---
TIMESTAMP=$(date +%Y%m%d%H%M%S)
IMAGE_NAME="ndb-${NDB_VERSION}-${DB_TYPE}-${DB_VERSION}-${OS_TYPE}-${OS_VERSION}-${TIMESTAMP}"

# --- Run Packer ---
echo "Starting Packer build for image: ${IMAGE_NAME}"

if [[ "$OS_TYPE" == "RHEL" ]]; then
  echo "--- Downloading RHEL image ---"
  TEMP_IMAGE_PATH="/tmp/rhel.qcow2"
  curl -L -o "$TEMP_IMAGE_PATH" "$SOURCE_IMAGE_URI"
  SOURCE_IMAGE_URI="file://${TEMP_IMAGE_PATH}"
fi

PACKER_CMD="packer build"
if [[ "$DEBUG" == "true" ]]; then
  PACKER_CMD="packer build -debug"
fi

$PACKER_CMD \
    -var "ansible_site_playbook=${ANSIBLE_SITE_PLAYBOOK}" \
    -var "ansible_config_path=${ANSIBLE_CONFIG_PATH}" \
  -var "ndb_version=${NDB_VERSION}" \
  -var "os_type=${OS_TYPE}" \
  -var "os_version=${OS_VERSION}" \
  -var "db_type=${DB_TYPE}" \
  -var "db_version=${DB_VERSION}" \
  -var "patroni_version=${PATRONI_VERSION}" \
  -var "etcd_version=${ETCD_VERSION}" \
  -var "source_image_uri=${SOURCE_IMAGE_URI}" \
  -var "image_name=${IMAGE_NAME}" \
  -var "ssh_public_key=$(cat packer/id_rsa.pub)" \
  packer/
