# Repository Guidelines

## How This Repository Works
This is a Windows dotfiles repo managed by `chezmoi` plus PowerShell automation.

1. Templates live under `home/` (`*.tmpl`, `dot_*`) and map to files in `%USERPROFILE%`.
2. `chezmoi apply` materializes those templates on the local machine.
3. `scripts/bootstrap.ps1` optionally installs tools, reapplies config, and syncs AI config folders.
4. `scripts/validate.ps1` enforces baseline integrity and secret-pattern checks (also in CI).

Recommended first run:

```powershell
chezmoi init --apply <github-user>/windots
pwsh ./scripts/bootstrap.ps1 -Mode full
pwsh ./scripts/validate.ps1
```

## Project Structure & Module Organization
- `home/`: source-of-truth templates for shell, git, terminal, editors, AI/MCP.
- `scripts/`: repo operations (`bootstrap`, `run-modules`, `validate`, `windots`, `export-current`) and shared helpers.
- `modules/<name>/`: module entrypoint plus module-owned scripts/config files.
- `docs/`: setup, migration, secrets, and architecture decisions.
- `home/dot_config/powershell/`: modular profile and workflow modules.
- `.github/workflows/validate.yml`: runs `scripts/validate.ps1` on push/PR.

## Build, Test, and Development Commands
- `chezmoi init --source .`: develop from local repo source.
- `chezmoi diff`: preview file changes.
- `chezmoi apply`: apply templates.
- `pwsh ./scripts/bootstrap.ps1 -Mode full`: full setup.
- `pwsh ./scripts/bootstrap.ps1 -Mode clean -SkipInstall`: reconfigure without package install.
- `pwsh ./modules/ai/link-configs.ps1 -UseSymlink`: symlink AI config dirs instead of copying.
- `pwsh ./scripts/validate.ps1`: mandatory validation before commit/PR.

## PowerShell Profile Behavior
- Modes: `full` (imports workflow modules) and `clean` (core only).
- Mode commands: `pmode`, `pclean`, `pfull`, `reload`.
- Workflow modules in `home/dot_config/powershell/modules/`:
  - `worktrees.psm1`
  - `time-tracker.psm1`
  - `pr-workflow.psm1`

## Coding Style & Naming Conventions
- PowerShell: 4-space indentation, `[CmdletBinding()]`, explicit `param(...)`.
- Scripts: kebab-case names for utility scripts and `module.ps1` for module entrypoints.
- Keep scripts idempotent and avoid host-specific hardcoding.
- Add new managed config under `home/dot_config/<tool>/...` when possible.

## Testing, Commits, and PRs
- No unit-test suite yet; validation is script-based and required.
- Commit style: Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`).
- PRs must include scope, impacted paths, and validation result.

## Security & Configuration Notes
- Never commit secrets, keys, or tokens.
- `.ai/` is ignored; keep local AI context there.
- Use `.local.*` files and external secret stores (see `docs/SECRETS.md`).
- Run `pwsh ./modules/secrets/migrate.ps1` when importing legacy environments.
