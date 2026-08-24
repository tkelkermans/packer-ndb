#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for packer-ndb (runs from repo root).
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

pip install --user --quiet 'ansible-core>=2.18' 'ansible-lint==26.6.0'

if ! command -v packer >/dev/null 2>&1; then
  curl -fsSL "https://releases.hashicorp.com/packer/1.15.4/packer_1.15.4_linux_amd64.zip" -o /tmp/packer.zip
  sudo unzip -o /tmp/packer.zip -d /usr/local/bin/
fi

if ! command -v shellcheck >/dev/null 2>&1; then
  SHELLCHECK_VERSION=v0.11.0
  curl -fsSL "https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VERSION}/shellcheck-${SHELLCHECK_VERSION}.linux.x86_64.tar.xz" | tar -xJ
  sudo install "shellcheck-${SHELLCHECK_VERSION}/shellcheck" /usr/local/bin/shellcheck
fi

if [[ ! -f packer/id_rsa || ! -f packer/id_rsa.pub ]]; then
  ssh-keygen -t rsa -b 4096 -C "packer@nutanix" -f packer/id_rsa -N "" -q
fi

packer init packer/
