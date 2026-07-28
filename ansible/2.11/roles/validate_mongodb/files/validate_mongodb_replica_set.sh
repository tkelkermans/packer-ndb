#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d /tmp/ndb-mongodb-replica-set.XXXXXX)

port_available() {
  local port=$1
  ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

choose_ports() {
  local count=$1
  local attempts=0 candidate duplicate port
  local -a ports=()

  while [[ ${#ports[@]} -lt $count && $attempts -lt 300 ]]; do
    candidate=$((20000 + RANDOM % 20000))
    duplicate=false
    for port in "${ports[@]}"; do
      if [[ "$port" == "$candidate" ]]; then
        duplicate=true
        break
      fi
    done
    if [[ "$duplicate" == false ]] && port_available "$candidate"; then
      ports+=("$candidate")
    fi
    attempts=$((attempts + 1))
  done

  if [[ ${#ports[@]} -ne $count ]]; then
    echo "Unable to find $count available localhost ports" >&2
    return 1
  fi

  printf '%s\n' "${ports[@]}"
}

pid_uses_tmpdir() {
  local pid=$1
  local cmdline
  [[ -r "/proc/$pid/cmdline" ]] || return 1
  cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline")
  [[ "$cmdline" == *"$TMPDIR"* ]]
}

cleanup() {
  local pid pid_file
  for pid_file in "$TMPDIR"/*.pid; do
    [[ -f "$pid_file" ]] || continue
    pid=$(cat "$pid_file")
    [[ -n "$pid" ]] || continue
    if kill -0 "$pid" >/dev/null 2>&1; then
      if ! pid_uses_tmpdir "$pid"; then
        echo "Skipping cleanup for PID $pid because it does not reference $TMPDIR" >&2
        continue
      fi
      kill "$pid" >/dev/null 2>&1 || true
      for _ in {1..10}; do
        kill -0 "$pid" >/dev/null 2>&1 || break
        sleep 1
      done
      kill -0 "$pid" >/dev/null 2>&1 && kill -9 "$pid" >/dev/null 2>&1 || true
    fi
  done
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

wait_for_primary() {
  local port=$1
  for _ in {1..60}; do
    if mongosh --quiet --port "$port" --eval 'db.hello().isWritablePrimary' 2>/dev/null | grep -q true; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for replica-set primary on port $port" >&2
  return 1
}

mapfile -t PORTS < <(choose_ports 1)
MONGOD_PORT=${PORTS[0]}

mkdir -p "$TMPDIR/data"

mongod --replSet rs0 --dbpath "$TMPDIR/data" --port "$MONGOD_PORT" --bind_ip 127.0.0.1 --fork --logpath "$TMPDIR/replica.log" --pidfilepath "$TMPDIR/replica.pid"
mongosh --quiet --port "$MONGOD_PORT" --eval "rs.initiate({_id:\"rs0\", members:[{_id:0, host:\"127.0.0.1:${MONGOD_PORT}\"}]})"
wait_for_primary "$MONGOD_PORT"
mongosh --quiet --port "$MONGOD_PORT" --eval 'rs.status().ok' | grep -q '^1$'
