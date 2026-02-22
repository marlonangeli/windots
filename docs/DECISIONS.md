# Decisions

## Core Approach

- `chezmoi` is the source-of-truth for dotfile templates under `home/`.
- PowerShell scripts orchestrate install/bootstrap/validation.
- Execution is module-based and dependency-resolved through `modules/module-registry.ps1`.
- Preflight checks run before install/update/restore flows via `scripts/common/preflight.ps1`.

## Installer Contracts

- Root canonical entrypoint: `install.ps1`
- Single installer implementation: `install.ps1`

Installer supports:

- action menu (`INSTALL`, `UPDATE`, `RESTORE`, `QUIT`) in interactive mode
- `-Action install|update|restore|quit` for automation
- `-Repo`
- `-Branch`
- `-Ref` (overrides `-Branch`)
- `-LocalRepoPath`

## Module Contracts

Each module has:

- name
- dependencies
- modes (`full`, `clean`)
- script path
- entry function

Entrypoints are located at `modules/<module>/module.ps1`.

## Package Management

Dependencies are declared in `modules/packages/repository.psd1`.

- Provider `winget` for system/apps
- Provider `mise` for CLI toolchain items

Each module installs/verifies only packages mapped to that module.
Interactive runs can prompt for module package defaults vs specific package selection.

## Winget Reliability

All `winget install/upgrade` calls go through `scripts/common/winget.ps1`.

Enforced behavior:

- `--source winget`
- agreement flags
- fallback for msstore certificate/source errors (`0x8a15005e`)

## Validation and Idempotency

- `scripts/validate.ps1` is the local integrity gate.
- `scripts/validate-modules.ps1` validates registry and dependency topology.
- `scripts/windots.ps1 -Command update` runs `chezmoi update`, post-bootstrap, validation, and `chezmoi verify`.
- `scripts/windots.ps1 -Command restore` replays installer/bootstrap from restore config and environment-backed secret references.
- `tests/run.ps1` runs validate + lint + pester + integration apply/verify/idempotency.
