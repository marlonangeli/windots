# windots

Windows dotfiles managed with `chezmoi` and PowerShell automation.

The project is module-driven, idempotent, and designed for repeatable local setup.

## Requirements

- Windows with `winget`
- PowerShell 7+
- Git
- `chezmoi`

Optional tools:

- `mise`
- `gum`
- `bw`

## Entrypoints

- Canonical remote entrypoint: `install.ps1` (repo root)
- Single installer implementation: `install.ps1`

Remote install:

```powershell
irm https://windots.ilegna.dev/install | iex
```

Interactive installer menu options:

- `INSTALL`
- `UPDATE`
- `RESTORE`
- `QUIT`

For automation, pass `-Action install` with flags like `-AutoApply` and `-NoPrompt`.

In interactive mode, package modules can prompt for default vs specific package selections (for example development runtimes like dotnet/node/bun/python).

## Quick Start

```powershell
chezmoi init --apply <github-user>/windots
pwsh ./scripts/bootstrap.ps1 -Mode full
pwsh ./scripts/validate.ps1
```

Safe update workflow:

```powershell
pwsh ./scripts/windots.ps1 -Command update
```

Restore workflow from config:

```powershell
pwsh ./scripts/windots.ps1 -Command restore -RestoreConfigPath "$env:LOCALAPPDATA\windots\state\restore.json"
```

## Installer Source Selection

`install.ps1` supports testing from branches, refs, and local paths:

```powershell
# branch
pwsh -NoProfile -File ./install.ps1 -Branch feature/my-change -AutoApply

# commit or tag (overrides branch)
pwsh -NoProfile -File ./install.ps1 -Ref <sha-or-tag> -AutoApply

# local repository (no push required)
pwsh -NoProfile -File ./install.ps1 -LocalRepoPath C:\src\windots -AutoApply
```

Safety guard for non-main testing:

```powershell
pwsh -NoProfile -File ./install.ps1 -RequireNonMain -Branch feature/my-change -AutoApply
```

## Module Architecture

Module registry:

- `modules/module-registry.ps1`

Module entrypoints:

- `modules/core/module.ps1`
- `modules/packages/module.ps1`
- `modules/shell/module.ps1`
- `modules/development/module.ps1`
- `modules/themes/module.ps1`
- `modules/terminal/module.ps1`
- `modules/ai/module.ps1`
- `modules/mise/module.ps1`
- `modules/secrets/module.ps1`
- `modules/validate/module.ps1`

Runner and orchestration:

- `scripts/run-modules.ps1`
- `scripts/bootstrap.ps1`
- `scripts/windots.ps1`

## Package Repository

Dependencies are declared in:

- `modules/packages/repository.psd1`

Providers:

- `modules/packages/provider-winget.ps1`
- `modules/packages/provider-mise.ps1`

Manager:

- `modules/packages/manager.ps1`

Each module installs/verifies only the packages mapped to it in the repository manifest.

## Winget Contract

All `winget install/upgrade` operations go through:

- `scripts/common/winget.ps1`

Behavior:

- Forces `--source winget`
- Always adds source/package agreement flags
- Adds fallback for msstore certificate/source failures (`0x8a15005e`)
- Logs command + exit code and fails fast on unrecoverable errors

## Validation and Tests

Local validation:

```powershell
pwsh -NoProfile -File ./scripts/validate.ps1
pwsh -NoProfile -File ./scripts/validate-modules.ps1
```

Local test runner:

```powershell
pwsh -NoProfile -File ./tests/run.ps1
```

`tests/run.ps1` runs:

- repository validation
- lint (`PSScriptAnalyzer`, if enabled)
- Pester tests
- integration sequence: `chezmoi apply`, `chezmoi verify`, second `chezmoi apply`, idempotency diff check

## Repository Layout

```text
home/      # chezmoi templates (source of truth)
scripts/   # orchestrators, validation, shared helpers
modules/   # per-module scripts and configs
tests/     # local test runner, pester, sandbox assets
docs/      # setup, migration, secrets, architecture notes
```

## Documentation

- [Setup](docs/SETUP.md)
- [Restore](docs/RESTORE.md)
- [Decisions](docs/DECISIONS.md)
- [Secrets](docs/SECRETS.md)
