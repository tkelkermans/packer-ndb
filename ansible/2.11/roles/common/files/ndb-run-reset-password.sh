#!/usr/bin/env bash
set -euo pipefail

script=/bin/reset_password.sh
log=/opt/era_base/era_startup.log
lock=/run/ndb-reset-password.lock
done_marker=/run/ndb-reset-password.done
wait_seconds=0
rc_local_exists=false
rc_local_references_reset=false
pam_token_user=""
pam_account_user=""
pam_password=""

if [[ "${1:-}" == "--pam-auth-token" ]]; then
  pam_token_user=${2:-era}
elif [[ "${1:-}" == "--pam-account" ]]; then
  pam_account_user=${2:-era}
elif [[ "${1:-}" == "--wait-for-script" ]]; then
  wait_seconds=${2:-150}
fi

mkdir -p /opt/era_base /run

run_reset_script() {
  if [[ ! -s "$script" ]]; then
    echo "NDB reset script exists but is empty: $script" >> "$log"
    return 1
  fi

  echo "Running NDB injected password reset helper for $script." >> "$log"

  if grep -qE '(^|[[:space:];|&])(/usr/bin/|/bin/)?passwd([[:space:]]+|[[:space:]]*[;|&]|$)' "$script"; then
    # NDB reset scripts can use interactive or Red Hat-style passwd forms.
    # Route those invocations through a Debian-safe chpasswd wrapper.
    sed -i -E 's#(^|[[:space:];|&])(/usr/bin/|/bin/)?passwd([[:space:]]+|[[:space:]]*[;|&]|$)#\1/usr/local/sbin/ndb-passwd-stdin\3#g' "$script"
  fi

  set +e
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin /bin/bash "$script" >> "$log" 2>&1
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    echo "NDB injected password reset failed with exit status $status." >> "$log"
    return "$status"
  fi

  return 0
}

set_password_from_pam_token() {
  local target_user=$1

  if [[ -z "$pam_password" ]]; then
    echo "NDB PAM password reset did not receive an auth token." >> "$log"
    return 1
  fi

  printf '%s:%s\n' "$target_user" "$pam_password" | /usr/sbin/chpasswd
  normalize_password_login_account "$target_user"
  echo "NDB PAM password reset completed for $target_user." >> "$log"
}

normalize_password_login_account() {
  local target_user=$1

  if [[ -x /usr/sbin/usermod ]]; then
    /usr/sbin/usermod --unlock "$target_user" >> "$log" 2>&1 || true
  fi

  if [[ -x /usr/bin/chage ]]; then
    /usr/bin/chage -E -1 -I -1 -m 0 -M 99999 "$target_user" >> "$log" 2>&1 || true
  fi

  echo "NDB PAM account normalization completed for $target_user." >> "$log"
}

wait_for_late_reset_intent() {
  local token_wait_seconds=${1:-150}

  if [[ ! "$token_wait_seconds" =~ ^[0-9]+$ ]] || (( token_wait_seconds <= 0 )); then
    token_wait_seconds=150
  fi

  echo "NDB PAM auth waiting for late injected reset script before password checks." >> "$log"
  for _ in $(seq 1 "$token_wait_seconds"); do
    if [[ -f "$script" ]] || grep -q '/bin/reset_password.sh' /etc/rc.local 2>/dev/null; then
      return 0
    fi
    sleep 1
  done

  return 1
}

exec 9>"$lock"
flock -w 300 9

reset_already_completed=false
if [[ -f "$done_marker" ]]; then
  reset_already_completed=true
fi

if grep -q '/bin/reset_password.sh' /etc/rc.local 2>/dev/null; then
  rc_local_references_reset=true
fi
if [[ -e /etc/rc.local ]]; then
  rc_local_exists=true
fi

if [[ -n "$pam_account_user" ]]; then
  if [[ "${PAM_USER:-}" != "$pam_account_user" ]]; then
    exit 0
  fi

  if [[ ! -f "$script" && "$rc_local_references_reset" != "true" && "$reset_already_completed" != "true" ]]; then
    exit 0
  fi

  if [[ "$reset_already_completed" != "true" && -f "$script" ]]; then
    if run_reset_script; then
      touch "$done_marker"
      echo "NDB injected password reset completed during PAM account check." >> "$log"
    else
      echo "NDB injected password reset failed during PAM account check; normalizing account state anyway." >> "$log"
    fi
  fi

  normalize_password_login_account "$pam_account_user"
  if [[ -f "$done_marker" ]]; then
    /usr/local/sbin/ndb-ssh-reset-gate unblock || true
  fi
  exit 0
fi

if [[ -n "$pam_token_user" ]]; then
  if [[ "${PAM_USER:-}" != "$pam_token_user" ]]; then
    exit 0
  fi

  if [[ ! -f "$script" && "$rc_local_references_reset" != "true" && "$rc_local_exists" == "true" ]]; then
    IFS= read -r pam_password || true
    if [[ -n "$pam_password" ]]; then
      echo "NDB PAM auth-token password reset triggered by NDB-created rc.local for $pam_token_user." >> "$log"
      set_password_from_pam_token "$pam_token_user"
      touch "$done_marker"
      /usr/local/sbin/ndb-ssh-reset-gate unblock || true
      exit 0
    fi
    wait_for_late_reset_intent 150 || true
    if grep -q '/bin/reset_password.sh' /etc/rc.local 2>/dev/null; then
      rc_local_references_reset=true
    fi
  fi

  if [[ ! -f "$script" && "$rc_local_references_reset" != "true" ]]; then
    exit 0
  fi

  IFS= read -r pam_password || true

  script_completed=false
  if [[ "$reset_already_completed" == "true" ]]; then
    script_completed=true
    echo "NDB injected password reset was already marked complete before PAM auth." >> "$log"
  elif [[ -f "$script" ]] && run_reset_script; then
    script_completed=true
    echo "NDB injected password reset completed." >> "$log"
  else
    echo "NDB injected password reset did not complete; using PAM auth-token password reset for $pam_token_user." >> "$log"
  fi

  if [[ -n "$pam_password" ]]; then
    echo "Applying PAM auth-token password reset for $pam_token_user." >> "$log"
    set_password_from_pam_token "$pam_token_user"
    touch "$done_marker"
    /usr/local/sbin/ndb-ssh-reset-gate unblock || true
    exit 0
  fi

  if [[ "$script_completed" == "true" ]]; then
    echo "PAM auth token unavailable; trusting completed NDB injected password reset." >> "$log"
    /usr/local/sbin/ndb-ssh-reset-gate unblock || true
    exit 0
  fi

  echo "PAM auth token unavailable and NDB injected password reset did not complete." >> "$log"
  exit 1
fi

if [[ "$reset_already_completed" == "true" ]]; then
  /usr/local/sbin/ndb-ssh-reset-gate unblock || true
  exit 0
fi

if [[ ! -f "$script" ]]; then
  if [[ "$rc_local_references_reset" != "true" ]]; then
    /usr/local/sbin/ndb-ssh-reset-gate unblock || true
    exit 0
  fi

  if [[ ! "$wait_seconds" =~ ^[0-9]+$ ]] || (( wait_seconds <= 0 )); then
    wait_seconds=300
  fi

  for _ in $(seq 1 "$wait_seconds"); do
    [[ -f "$script" ]] && break
    sleep 1
  done

  if [[ ! -f "$script" ]]; then
    echo "NDB reset script was referenced by /etc/rc.local but did not appear before timeout." >> "$log"
    exit 1
  fi
fi

run_reset_script

touch "$done_marker"
/usr/local/sbin/ndb-ssh-reset-gate unblock || true
echo "NDB injected password reset completed." >> "$log"
