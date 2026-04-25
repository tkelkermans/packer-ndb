#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d /tmp/ndb-mongodb-sharded.XXXXXX)

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
  echo "Timed out waiting for primary on port $port" >&2
  return 1
}

wait_for_mongos() {
  local port=$1
  for _ in {1..60}; do
    if mongosh --quiet --port "$port" --eval 'db.adminCommand({ping:1}).ok' 2>/dev/null | grep -q 1; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for mongos on port $port" >&2
  return 1
}

mapfile -t PORTS < <(choose_ports 3)
CONFIG_PORT=${PORTS[0]}
SHARD_PORT=${PORTS[1]}
MONGOS_PORT=${PORTS[2]}

mkdir -p "$TMPDIR/config" "$TMPDIR/shard"

mongod --configsvr --replSet cfg --dbpath "$TMPDIR/config" --port "$CONFIG_PORT" --bind_ip 127.0.0.1 --fork --logpath "$TMPDIR/config.log" --pidfilepath "$TMPDIR/config.pid"
mongod --shardsvr --replSet shard1 --dbpath "$TMPDIR/shard" --port "$SHARD_PORT" --bind_ip 127.0.0.1 --fork --logpath "$TMPDIR/shard.log" --pidfilepath "$TMPDIR/shard.pid"

mongosh --quiet --port "$CONFIG_PORT" --eval "rs.initiate({_id:\"cfg\", configsvr:true, members:[{_id:0, host:\"127.0.0.1:${CONFIG_PORT}\"}]})"
mongosh --quiet --port "$SHARD_PORT" --eval "rs.initiate({_id:\"shard1\", members:[{_id:0, host:\"127.0.0.1:${SHARD_PORT}\"}]})"
wait_for_primary "$CONFIG_PORT"
wait_for_primary "$SHARD_PORT"

mongos --configdb "cfg/127.0.0.1:${CONFIG_PORT}" --bind_ip 127.0.0.1 --port "$MONGOS_PORT" --fork --logpath "$TMPDIR/mongos.log" --pidfilepath "$TMPDIR/mongos.pid"
wait_for_mongos "$MONGOS_PORT"

mongosh --quiet --port "$MONGOS_PORT" --eval "sh.addShard(\"shard1/127.0.0.1:${SHARD_PORT}\")"
mongosh --quiet --port "$MONGOS_PORT" --eval 'db.adminCommand({listShards:1}).shards.length' | grep -Eq '^[1-9][0-9]*$'
