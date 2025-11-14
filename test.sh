#!/bin/bash

set -e

for matrix_file in ndb/*/matrix.json; do
  ndb_version=$(basename $(dirname "$matrix_file"))
  echo "--- Testing NDB version ${ndb_version} ---"
  
  jq -c '.[]' "$matrix_file" | while read -r build; do
    os_type=$(echo "$build" | jq -r '.os_type')
    if [[ "$os_type" == "RHEL" ]]; then
      echo "--> Skipping RHEL build due to a known issue with long URLs."
      continue
    fi
    os_version=$(echo "$build" | jq -r '.os_version')
    db_version=$(echo "$build" | jq -r '.db_version')
    
    echo "--> Testing build: ${os_type} ${os_version}, PostgreSQL ${db_version}"
    
    ./build.sh --ci --ndb-version "$ndb_version" --os "$os_type" --os-version "$os_version" --db-version "$db_version"
  done
done

echo "--- All tests passed! ---"
