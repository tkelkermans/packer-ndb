#!/usr/bin/env bash
set -euo pipefail

normalize_password_login_account() {
  local user=$1

  if [[ -x /usr/sbin/usermod ]]; then
    /usr/sbin/usermod --unlock "$user" 2>/dev/null || true
  fi

  if [[ -x /usr/bin/chage ]]; then
    /usr/bin/chage -E -1 -I -1 -m 0 -M 99999 "$user" 2>/dev/null || true
  fi
}

args=()
for arg in "$@"; do
  case "$arg" in
    --stdin)
      ;;
    *)
      args+=("$arg")
      ;;
  esac
done

arg_count=0
for _ in "${args[@]}"; do
  arg_count=$((arg_count + 1))
done

if [[ "$arg_count" -eq 1 && "${args[0]}" != -* ]]; then
  user=${args[0]}
  IFS= read -r password || true
  if [[ -z "$password" ]]; then
    echo "No password supplied on stdin for $user" >&2
    exit 1
  fi
  printf '%s:%s\n' "$user" "$password" | /usr/sbin/chpasswd
  normalize_password_login_account "$user"
  exit 0
fi

exec /usr/bin/passwd "$@"
