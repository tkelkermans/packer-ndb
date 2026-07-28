# Security Policy

## Reporting a vulnerability

Please do **not** open a public issue for suspected vulnerabilities.
Use GitHub's private vulnerability reporting on this repository
(Security → Report a vulnerability), which reaches the maintainer directly.

## Scope notes

- This project builds VM gold images; the highest-impact class of issue is
  anything that leaks credentials/keys into a captured image or manifest,
  or that leaves access enabled in a provisioned clone. Reports in that
  class are prioritized.
- No secrets belong in this repository: builds read credentials only from
  the environment (`op run --env-file=.env`), manifests must never record
  secret values, and `actionArguments` payload values are never logged.
- TLS verification to Prism Central is on by default; labs with
  self-signed certificates opt in via `PKR_VAR_nutanix_insecure=true`.
