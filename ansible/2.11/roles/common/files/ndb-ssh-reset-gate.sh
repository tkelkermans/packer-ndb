#!/usr/bin/env bash
set -euo pipefail

log=/opt/era_base/era_startup.log
table=ndb_ssh_reset_gate
done_marker=/run/ndb-reset-password.done

mkdir -p /opt/era_base /run

reset_intent_present() {
  [[ -f /bin/reset_password.sh ]] || grep -q '/bin/reset_password.sh' /etc/rc.local 2>/dev/null
}

ensure_nft_available() {
  if ! command -v nft >/dev/null 2>&1; then
    echo "nft command is unavailable; cannot apply NDB SSH reset gate." >> "$log"
    return 1
  fi
}

unblock_gate() {
  if command -v nft >/dev/null 2>&1; then
    nft delete table inet "$table" 2>/dev/null || true
  fi
}

gate_is_active() {
  command -v nft >/dev/null 2>&1 && nft list table inet "$table" >/dev/null 2>&1
}

block_gate() {
  ensure_nft_available
  nft delete table inet "$table" 2>/dev/null || true
  nft add table inet "$table"
  nft "add chain inet $table input { type filter hook input priority -300; policy accept; }"
  nft add rule inet "$table" input tcp dport 22 drop
  echo "NDB SSH reset gate blocked inbound port 22 until password reset completion." >> "$log"
}

validate_block_rule() {
  ensure_nft_available
  printf 'add table inet %s\nadd chain inet %s input { type filter hook input priority -300; policy accept; }\nadd rule inet %s input tcp dport 22 drop\n' "$table" "$table" "$table" | nft --check -f -
}

case "${1:-}" in
  block)
    block_gate
    ;;
  block-if-reset-intent)
    if [[ -f "$done_marker" ]]; then
      unblock_gate
    elif reset_intent_present; then
      block_gate
    else
      unblock_gate
    fi
    ;;
  unblock)
    unblock_gate
    echo "NDB SSH reset gate unblocked inbound port 22." >> "$log"
    ;;
  validate-block-rule)
    validate_block_rule
    ;;
  *)
    echo "Usage: $0 {block|block-if-reset-intent|unblock|validate-block-rule}" >&2
    exit 2
    ;;
esac
