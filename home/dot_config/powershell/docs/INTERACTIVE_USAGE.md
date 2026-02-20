# Interactive Usage

## How Interactive Mode Works

Main workflow functions accept direct parameters or prompt for missing values.

```powershell
New-Worktree
Start-Work
New-Feature
New-PR
```

Use built-in help for parameters and examples:

```powershell
Get-Help New-Worktree -Full
Get-Help Start-Work -Examples
Get-Help New-PR -Parameter *
```

## Worktrees (`worktrees.psm1`)

Primary functions:

- `Get-Worktree`
- `New-Worktree`
- `Remove-Worktree`
- `Open-Worktree`
- `Get-WorktreeStatus`
- `Switch-Worktree`
- `Clear-Worktree`
- `New-WorktreeAI`

Aliases: `gwt`, `gwtn`, `gwtr`, `gwto`, `gwts`, `gwtw`, `gwt-ai`.

## Time Tracking (`time-tracker.psm1`)

Primary functions:

- `Start-Work`
- `Pause-Work`
- `Resume-Work`
- `Show-Work`
- `Stop-Work`
- `Reset-Work`

Aliases: `ws`, `wp`, `wr`, `wt`, `we`, `work-start`, `work-stop`, `work-show`.

## PR Workflow (`pr-workflow.psm1`)

Primary functions:

- `New-Feature`
- `Test-MergeConflict` / `Test-DevConflict`
- `New-MergeBranch`
- `New-PR`
- `Complete-Feature`
- `Get-MyPRs`

Aliases: `nf`, `npr`, `cf`, `prs`.

## Practical Tips

- Use `-Interactive` when available to force guided prompts.
- Prefer `-IssueKey` for traceability in branch names and PR titles.
- Run `Get-Help <command> -Examples` before first use.
- Keep profile mode in `full` for daily workflow and `clean` for troubleshooting.

## References

- [PowerShell docs index](./README.md)
- [PR workflow details](./PR_WORKFLOW.md)
- [Time tracking details](./TIME_TRACKING.md)
