# Lessons

- When Prism-side image imports are slow, do not keep retrying local uploads over VPN. Prefer reusing or pre-staging cluster images via `source_image_name`, because the remote import can finish successfully after the local Packer wait path becomes misleading.
- When validating a saved Prism image by cloning it into a disposable VM, base64-encode the cloud-init `user_data` and explicitly power the VM on after the create task succeeds. A raw, non-base64 guest customization payload can fail server-side, and a successful clone request may still leave the VM powered off until you update `spec.resources.power_state` to `ON`.
- Keep the project operator-facing toolchain limited to Packer, Terraform, Ansible, and shell. Avoid adding Python helper packages for orchestration unless the user explicitly approves it, because extra languages raise the readability and maintenance burden for this repo.
- Every behavior change must update the README in the same work item. The README should stay simple, beginner-friendly, and explicit enough that a new operator can understand what the tool does and exactly how to run it.
- Before asking subagents to verify or commit, make sure the branch has a committed baseline for files their task depends on. Do not let a task pass only because important matrices, Ansible trees, or source files are untracked in the local working tree.
- When a missing env value is reported fixed through a 1Password mount, verify both that the key exists and that `op run --env-file .env` resolves a non-empty value before launching expensive live matrix runs.
