# Contributing

This is a matrix-driven Packer + Ansible image factory for Nutanix Database
Service (NDB) gold images. The README is the authoritative long-form
reference; this file is the short version for getting a change landed.

## One-time setup

```bash
ssh-keygen -t rsa -b 4096 -C "packer@nutanix" -f packer/id_rsa -N ""
packer init packer/
cp .env.example .env   # or wire up 1Password (see below)
```

Helper scripts are **Bash, not zsh** (they use `${!var}` indirect expansion)
and stay portable to bash 3.2.

## Secrets

`.env` may be a 1Password-managed named pipe. **Never read it directly**
(`cat`, `sed`, `source`) — reads block forever. Run exactly one serialized
`op run --env-file=.env -- <command>` at a time. `.env.example` is the safe
schema reference. Never print NDB payload `actionArguments` values; redact
fields whose names include `password`, `secret`, `key`, or `token`.

## Static gates (run before claiming anything works)

```bash
bash -n build.sh test.sh scripts/*.sh scripts/selftests/*.sh
printf '%s\n' build.sh test.sh scripts/*.sh scripts/selftests/*.sh | xargs -n1 shellcheck -S warning
jq empty images.json ndb/*/matrix.json
scripts/matrix_validate.sh ndb/*/matrix.json
bash scripts/selftest.sh            # supports --filter REGEX
packer fmt -check packer/
for v in ansible/*/; do ANSIBLE_ROLES_PATH="$v/roles" ansible-playbook --syntax-check "$v/playbooks/site.yml"; done
ANSIBLE_ROLES_PATH=ansible/2.10/roles ansible-lint --profile basic ansible/2.10
git diff --check
```

CI (`.github/workflows/ci.yml`) runs the same gates credential-free on every
PR. Run shellcheck **per file** — a multi-file invocation cross-contaminates
its variable analysis (false SC2178/SC2128).

## Ground rules

- `ndb/<ver>/matrix.json` is the single source of truth; it mirrors the NDB
  release notes. Never qualify a version the vendor release notes do not.
- Ansible changes land **identically** in every `ansible/<ver>/` tree; the
  selftest drift gate enforces byte-lockstep outside a small allowlist.
  New NDB versions come from `scripts/release_scaffold.sh`, never hand-copies.
- Images must not boot with the packaged database service enabled or its
  port bound — NDB owns the runtime. `image_prepare` enforces this at
  capture; do not weaken it.
- Live validation (builds, artifact validation, E2E) needs a Nutanix lab.
  Changes that alter live behavior must say so in the PR and list the
  commands a lab owner should run.
- `docs/operational-lessons.md` records hard-won operational behavior;
  read it before touching NDB-, PAM-, or storage-related code and extend it
  when you learn something the hard way.

## Tests

Structural and functional checks live in `scripts/selftests/*.sh` and run
via `bash scripts/selftest.sh`. Add a failing check first when fixing a bug
the suite should have caught; suite functions are `run_<topic>_tests` and
duplicate names fail the run.
