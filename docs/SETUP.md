# Setup

## Quick Install

Remote entrypoint:

```powershell
irm https://windots.ilegna.dev/install | iex
```

Local execution:

```powershell
pwsh -NoProfile -File ./install.ps1
```

Direct GitHub raw fallback:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/marlonangeli/windots/main/install.ps1")))
```

## Installer Actions

Interactive menu options:

- `INSTALL`
- `UPDATE`
- `RESTORE`
- `QUIT`

Non-interactive examples:

```powershell
pwsh -NoProfile -File ./install.ps1 -Action install -AutoApply -NoPrompt
pwsh -NoProfile -File ./install.ps1 -Action update -NoPrompt
pwsh -NoProfile -File ./install.ps1 -Action restore -RestoreConfigPath "$env:LOCALAPPDATA\windots\state\restore.json" -NoPrompt
```

## Source Selection for Testing

```powershell
# branch
pwsh -NoProfile -File ./install.ps1 -Branch feature/my-change -AutoApply

# commit/tag (overrides branch)
pwsh -NoProfile -File ./install.ps1 -Ref <sha-or-tag> -AutoApply

# local repository source
pwsh -NoProfile -File ./install.ps1 -LocalRepoPath "C:\src\windots" -AutoApply
```

Safety guard to avoid accidental main-branch runs:

```powershell
pwsh -NoProfile -File ./install.ps1 -RequireNonMain -Branch feature/my-change -AutoApply
```

## Manual Bootstrap

```powershell
pwsh ./scripts/bootstrap.ps1 -Mode full
```

Useful flags:

- `-Mode clean`
- `-SkipInstall`
- `-SkipMise`
- `-Modules core,shell,terminal`
- `-IncludeSecretsChecks`

## Day-2 Operations

```powershell
pwsh ./scripts/windots.ps1 -Command update
pwsh ./scripts/windots.ps1 -Command apply
pwsh ./scripts/windots.ps1 -Command bootstrap -Mode clean
pwsh ./scripts/windots.ps1 -Command restore -RestoreConfigPath "$env:LOCALAPPDATA\windots\state\restore.json"
pwsh ./scripts/windots.ps1 -Command validate
```

`update` and `apply` workflows both run validation and `chezmoi verify` after orchestration.

## Validation

```powershell
pwsh -NoProfile -File ./scripts/validate.ps1
pwsh -NoProfile -File ./scripts/validate-modules.ps1
pwsh -NoProfile -File ./tests/run.ps1
```

What is validated:

- required files and module contracts
- module dependency graph
- secret-pattern checks in managed script/template trees
- idempotency via integration workflow in `tests/run.ps1`

## Module Utility Scripts

- Profile shim
  - `pwsh ./modules/shell/profile-shim.ps1 -Action status`
  - `pwsh ./modules/shell/profile-shim.ps1 -Action reset`
- AI config sync
  - `pwsh ./modules/ai/link-configs.ps1`
  - `pwsh ./modules/ai/link-configs.ps1 -UseSymlink`
- Secrets helpers
  - `pwsh ./modules/secrets/migrate.ps1`
  - `pwsh ./modules/secrets/deps-check.ps1`
  - `pwsh ./modules/secrets/install-jira-cli.ps1` (optional, installs from GitHub release)

## Winget Behavior

Managed `winget` operations are routed through `scripts/common/winget.ps1`.

- source forced to `winget`
- agreement flags appended by default
- package-specific install overrides are supported (for example VS Build Tools workloads)
- fallback path for msstore certificate/source failures
- operation logging and explicit exit-code handling

For restore config contract and examples, see `docs/RESTORE.md`.
