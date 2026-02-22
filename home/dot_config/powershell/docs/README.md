# PowerShell Profile Documentation

## Overview

This profile is loaded from `home/dot_config/powershell/Microsoft.PowerShell_profile.ps1` and supports two modes:

- `full`: imports `worktrees`, `time-tracker`, and `pr-workflow`
- `clean`: loads only core config, aliases, and utils

Mode commands:

```powershell
pmode
pclean
pfull
reload
```

## Directory Layout

```text
home/dot_config/powershell/
  Microsoft.PowerShell_profile.ps1
  modules/
    config.ps1
    aliases.ps1
    utils.ps1
    worktrees.psm1
    time-tracker.psm1
    pr-workflow.psm1
  docs/
```

## Module Summary

- `config.ps1`: env vars, PSReadLine, lazy Oh-My-Posh, lazy zoxide/mise
- `aliases.ps1`: git/docker/dotnet/node/navigation shortcuts
- `utils.ps1`: helper commands (`la`, `ll`, `mkcd`, `edit`, `ep`, `reload`)
- `worktrees.psm1`: create/open/remove/list/switch git worktrees
- `time-tracker.psm1`: start/stop/pause/resume/reset work timers and Jira log
- `pr-workflow.psm1`: branch + PR workflow for Azure DevOps

## Quick Commands

```powershell
# Worktrees
New-Worktree -BranchName feat/AL-123-example
Get-WorktreeStatus

# Time tracking
Start-Work -IssueKey AL-123 -Description "Implement auth"
Pause-Work
Resume-Work
Stop-Work -IssueKey AL-123

# PR workflow
New-Feature -Name "oauth" -Type feat -IssueKey AL-123
Test-DevConflict
New-PR -Target develop -IssueKey AL-123
```

## Related Docs

- [Interactive usage](./INTERACTIVE_USAGE.md)
- [PR workflow](./PR_WORKFLOW.md)
- [Time tracking](./TIME_TRACKING.md)
- [Changelog](./CHANGELOG.md)
