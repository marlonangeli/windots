# Shared AI Context

Prefer small, reversible changes. Keep commands explicit, scripts idempotent, and documentation close to the code it explains.

For this machine, `windots` owns dotfiles and setup. The `ilegna` CLI owns day-to-day workflow helpers such as worktrees, PRs, pipelines, and Jira time notes.

Default terminal workflow:

- PowerShell loads `~/.config/powershell/profile.d/*.ps1`.
- `mise` uses shims by default; run `MISE_ACTIVATE=1 pwsh` only when prompt-time activation is needed.
- `starship` and `zoxide` initialize in interactive PowerShell sessions.
- OpenCode is preferred from a terminal or WSL when Windows terminal behavior gets in the way.
