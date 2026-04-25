#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d /tmp/ndb-mongodb-sharded.XXXXXX)

cleanup() {
  local pid pid_file
  for pid_file in "$TMPDIR"/*.pid; do
    [[ -f "$pid_file" ]] || continue
    pid=$(cat "$pid_file")
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
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
  for _ in {1..60}; do
    if mongosh --quiet --port 27093 --eval 'db.adminCommand({ping:1}).ok' 2>/dev/null | grep -q 1; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for mongos" >&2
  return 1
}

mkdir -p "$TMPDIR/config" "$TMPDIR/shard"

mongod --configsvr --replSet cfg --dbpath "$TMPDIR/config" --port 27091 --bind_ip 127.0.0.1 --fork --logpath "$TMPDIR/config.log" --pidfilepath "$TMPDIR/config.pid"
mongod --shardsvr --replSet shard1 --dbpath "$TMPDIR/shard" --port 27092 --bind_ip 127.0.0.1 --fork --logpath "$TMPDIR/shard.log" --pidfilepath "$TMPDIR/shard.pid"

mongosh --quiet --port 27091 --eval 'rs.initiate({_id:"cfg", configsvr:true, members:[{_id:0, host:"127.0.0.1:27091"}]})'
mongosh --quiet --port 27092 --eval 'rs.initiate({_id:"shard1", members:[{_id:0, host:"127.0.0.1:27092"}]})'
wait_for_primary 27091
wait_for_primary 27092

mongos --configdb cfg/127.0.0.1:27091 --bind_ip 127.0.0.1 --port 27093 --fork --logpath "$TMPDIR/mongos.log" --pidfilepath "$TMPDIR/mongos.pid"
wait_for_mongos

mongosh --quiet --port 27093 --eval 'sh.addShard("shard1/127.0.0.1:27092")'
mongosh --quiet --port 27093 --eval 'db.adminCommand({listShards:1}).shards.length' | grep -Eq '^[1-9][0-9]*$'
