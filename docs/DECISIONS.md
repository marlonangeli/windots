# Decisions

## 1) Source of Truth

- `chezmoi` templates in `home/` are canonical.
- Runtime setup is orchestrated by PowerShell scripts, not by ad-hoc one-off commands.

## 2) Single Installer Contract

- Root entrypoint is `install.ps1`.
- Installer supports interactive action menu and non-interactive `-Action` mode.
- Action set is stable: `install`, `update`, `restore`, `quit`.

## 3) Module-Centric Execution

- Module registry lives in `modules/module-registry.ps1`.
- Every module defines dependencies, supported modes (`full`, `clean`), script path, and entry function.
- Execution plan is dependency-resolved and run through `scripts/run-modules.ps1`.

## 4) Package Repository Pattern

- Package declarations live in `modules/packages/repository.psd1`.
- Providers:
  - `winget` for system/apps
  - `mise` for runtime toolchain
- Modules install only their mapped package subset.
- Interactive mode can choose defaults or optional package subsets.

## 5) Preflight Before Mutation

- Preflight checks run before install/update/restore via `scripts/common/preflight.ps1`.
- Checks include command availability, winget source health, network reachability, execution-policy visibility, and chezmoi initialization status for day-2 actions.

## 6) Winget Reliability Wrapper

- Managed winget operations go through `scripts/common/winget.ps1`.
- Wrapper behavior:
  - forces `--source winget`
  - appends source/package agreement flags
  - handles fallback for msstore certificate/source failures (`0x8a15005e`)
  - logs command and exit code for troubleshooting

## 7) Validation and Idempotency Gates

- `scripts/validate.ps1` is the main local integrity gate.
- `scripts/validate-modules.ps1` validates module registry/dependency topology.
- `tests/run.ps1` executes validation, optional lint, pester tests, and integration idempotency checks.
- `scripts/windots.ps1 -Command update` and `-Command apply` both complete with validation and `chezmoi verify`.

## 8) Restore Contract

- `scripts/windots.ps1 -Command restore` replays installation/bootstrap from restore config.
- Restore config supports installer source options plus environment-backed secret references (`secretEnv`).
- Raw secrets are intentionally excluded from tracked restore config.
