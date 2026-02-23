# windots

```text
██╗    ██╗██╗███╗   ██╗██████╗  ██████╗ ████████╗███████╗
██║    ██║██║████╗  ██║██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝
██║ █╗ ██║██║██╔██╗ ██║██║  ██║██║   ██║   ██║   ███████╗
██║███╗██║██║██║╚██╗██║██║  ██║██║   ██║   ██║   ╚════██║
╚███╔███╔╝██║██║ ╚████║██████╔╝╚██████╔╝   ██║   ███████║
 ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═════╝  ╚═════╝    ╚═╝   ╚══════╝
```

Windows dotfiles managed with `chezmoi` and PowerShell automation.

The repo is module-driven, idempotent, and designed for repeatable machine setup.

## Why windots

- Single entrypoint (`install.ps1`) for first install and day-2 operations.
- Guided action menu (`INSTALL`, `UPDATE`, `RESTORE`, `QUIT`) with non-interactive flags.
- Module orchestration with explicit dependency order.
- Preflight checks and validation gates to reduce setup drift and surprises.

## Requirements

- Windows with `winget` available
- PowerShell 7+
- Git
- [`chezmoi`](https://www.chezmoi.io/)

These are checked during installer preflight (`scripts/common/preflight.ps1`).

Optional tools:

- [`mise`](https://mise.jdx.dev)
- [`gum`](https://github.com/charmbracelet/gum)
- [`bw`](https://bitwarden.com/help/cli/)
- [`fzf`](https://github.com/junegunn/fzf) (used by `zi`/zoxide interactive jump)
- [`usage`](https://github.com/jdx/usage) (installed via `mise` as `cargo:usage-cli`)
- Visual Studio Build Tools 2022 with C++ workload (needed for cargo-built CLI tools on Windows)

## Installation

Canonical remote install:

```powershell
irm https://windots.ilegna.dev/install | iex
```

Direct GitHub raw fallback:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/marlonangeli/windots/main/install.ps1")))
```

Run locally:

```powershell
pwsh -NoProfile -File ./install.ps1
```

## Installer Actions

Interactive menu:

- `INSTALL`: installs prerequisites, initializes source, runs bootstrap/validation.
- `UPDATE`: runs safe update flow (`chezmoi update` + bootstrap + validation + verify).
- `RESTORE`: replays install/bootstrap from restore config + secret env references.
- `QUIT`: exits without changes.

Non-interactive examples:

```powershell
# unattended install
pwsh -NoProfile -File ./install.ps1 -Action install -AutoApply -NoPrompt

# unattended update
pwsh -NoProfile -File ./install.ps1 -Action update -NoPrompt

# unattended restore with explicit config
pwsh -NoProfile -File ./install.ps1 -Action restore -RestoreConfigPath "$env:LOCALAPPDATA\windots\state\restore.json" -NoPrompt
```

Passing arguments from remote invocation:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/marlonangeli/windots/main/install.ps1"))) -Action install -AutoApply -NoPrompt -Mode full
```

## Source Selection for Testing

`install.ps1` supports testing from branch, ref, and local source:

```powershell
# branch
pwsh -NoProfile -File ./install.ps1 -Branch feature/my-change -AutoApply

# tag/commit (overrides branch)
pwsh -NoProfile -File ./install.ps1 -Ref <sha-or-tag> -AutoApply

# local repository
pwsh -NoProfile -File ./install.ps1 -LocalRepoPath "C:\src\windots" -AutoApply
```

Safety guard for non-main validation:

```powershell
pwsh -NoProfile -File ./install.ps1 -RequireNonMain -Branch feature/my-change -AutoApply
```

`-RequireNonMain` fails fast if you accidentally run against `main` without an explicit `-Ref` or `-LocalRepoPath`.

## Architecture

Module registry:

- `modules/module-registry.ps1`

High-level flow:

```text
install.ps1
  -> scripts/windots.ps1 (update/restore paths)
  -> scripts/bootstrap.ps1 (module runner entry)
      -> scripts/run-modules.ps1
          -> modules/<name>/module.ps1
              -> modules/packages/manager.ps1 (when module declares packages)
```

Main modules:

- `core`: base orchestration and chezmoi apply workflow
- `packages`: shared package operations
- `shell`: PowerShell profile and shell tooling
- `development`: runtime/toolchain selection (dotnet/node/bun/python)
- `themes`, `terminal`, `ai`, `mise`, `secrets`, `validate`

## Package Management

Package source of truth:

- `modules/packages/repository.psd1`

Providers:

- `modules/packages/provider-winget.ps1`
- `modules/packages/provider-mise.ps1`

Manager:

- `modules/packages/manager.ps1`

How it works:

- Each package declares provider, package id, module mapping, modes, and required/optional state.
- Modules install only packages mapped to themselves.
- Interactive flows can choose default package set or specific optional packages.

## Winget Contract

All managed `winget install/upgrade` operations flow through:

- `scripts/common/winget.ps1`

Behavior:

- Forces `--source winget`
- Appends source/package agreement flags
- Handles msstore certificate/source fallback (`0x8a15005e`)
- Logs command and exit code, fails fast on unrecoverable errors

## Day-2 Commands

```powershell
pwsh ./scripts/windots.ps1 -Command update
pwsh ./scripts/windots.ps1 -Command apply
pwsh ./scripts/windots.ps1 -Command bootstrap -Mode clean
pwsh ./scripts/windots.ps1 -Command restore -RestoreConfigPath "$env:LOCALAPPDATA\windots\state\restore.json"
pwsh ./scripts/windots.ps1 -Command validate
```

## Validation and Tests

Local validation:

```powershell
pwsh -NoProfile -File ./scripts/validate.ps1
pwsh -NoProfile -File ./scripts/validate-modules.ps1
```

Full local test runner:

```powershell
pwsh -NoProfile -File ./tests/run.ps1
```

`tests/run.ps1` covers:

- repository validation
- optional lint (`PSScriptAnalyzer`)
- Pester test suite
- integration idempotency sequence (`chezmoi apply/verify/apply/diff`)

## Repository Layout

```text
home/      # chezmoi templates (dotfiles + app configs)
scripts/   # installer/orchestration/validation/common helpers
modules/   # module entrypoints + module-owned automation
tests/     # smoke, pester, integration runner assets
docs/      # operational docs and architecture notes
```

## Documentation

- [Setup](docs/SETUP.md)
- [Restore](docs/RESTORE.md)
- [Decisions](docs/DECISIONS.md)
- [Secrets](docs/SECRETS.md)
