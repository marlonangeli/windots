# Changelog - PowerShell Profile

## 2026-02 Snapshot

This documentation set was synchronized with the current implementation in:

- `home/dot_config/powershell/Microsoft.PowerShell_profile.ps1`
- `home/dot_config/powershell/modules/worktrees.psm1`
- `home/dot_config/powershell/modules/time-tracker.psm1`
- `home/dot_config/powershell/modules/pr-workflow.psm1`

## Current Functional Scope

- Profile modes: `full` and `clean`
- Worktree workflow: list/create/open/remove/switch/prune + AI context creation
- Time tracking: start/show/pause/resume/stop/reset + Jira worklog integration
- PR workflow: feature branch creation, conflict checks, merge branch, PR creation, and completion helper

## Documentation Cleanup Included

- Removed references to non-existent files (for example `WORKTREES.md`, `old/` backups)
- Updated examples to current function names and aliases
- Added cross-links between PowerShell docs, root docs, and module source files
