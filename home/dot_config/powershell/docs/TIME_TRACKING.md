# Time Tracking with Jira

## Overview

`time-tracker.psm1` tracks active work in-memory via `$global:__TimeTracker` and can log work to Jira CLI.

Current state fields:

- `Start`
- `IssueKey`
- `Description`
- `PausedAt`
- `PausedDuration`

## Main Commands

### Start work

```powershell
Start-Work
Start-Work -IssueKey AL-123 -Description "Implement auth"
Start-Work -NoPrompt
```

### Pause and resume

```powershell
Pause-Work
Resume-Work
```

### Check active timer

```powershell
Show-Work
```

### Stop and optionally log

```powershell
Stop-Work
Stop-Work -IssueKey AL-123
Stop-Work -IssueKey AL-123 -Comment "Finished implementation"
Stop-Work -NoLog
Stop-Work -Force
```

Notes:

- If elapsed time is greater than 12 hours, `Stop-Work` asks confirmation unless `-Force`.
- When logging, command format is equivalent to:

```powershell
jira issue worklog add AL-123 "2h 30m" --comment "..." --no-input
```

### Reset state

```powershell
Reset-Work
```

## Aliases

- `ws` -> `Start-Work`
- `wp` -> `Pause-Work`
- `wr` -> `Resume-Work`
- `wt` -> `Show-Work`
- `we` -> `Stop-Work`
- `work-start`, `work-stop`, `work-show`

## References

- [Interactive usage](./INTERACTIVE_USAGE.md)
- [PR workflow](./PR_WORKFLOW.md)
- [Module source](../modules/time-tracker.psm1)
