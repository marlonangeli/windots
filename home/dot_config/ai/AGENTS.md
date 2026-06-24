# Shared AI Context

Prefer small, reversible changes. Keep commands explicit, scripts idempotent, and documentation close to the code it explains.

For this machine, `windots` owns dotfiles and setup. The `ilegna` CLI owns day-to-day workflow helpers such as worktrees, PRs, pipelines, and Jira time notes.

Default terminal workflow:

- PowerShell loads `~/.config/powershell/profile.d/*.ps1`.
- `mise` shims stay in PATH and PowerShell activates mise by default; set `WINDOTS_ENABLE_MISE_ACTIVATION=0` for shells that should use shims only.
- Starship loads by default from cached init; zoxide initializes lazily on first `z` or `zi`.
- OpenCode is preferred from a terminal or WSL when Windows terminal behavior gets in the way.
