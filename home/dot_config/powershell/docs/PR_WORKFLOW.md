# PR Workflow (Azure DevOps)

## Branch Strategy

Default workflow in `pr-workflow.psm1`:

1. Create feature branch from `main`
2. Validate merge compatibility with `develop`
3. Open PR to `develop`
4. After merge, open PR to `main`

## Main Commands

### Create branch

```powershell
New-Feature -Name "user-auth" -Type feat -IssueKey AL-123
New-Feature -Name "fix-login" -Type fix -IssueKey AL-456 -Worktree
```

`Type` accepted values: `feat`, `fix`, `hotfix`, `refactor`, `docs`, `test`, `chore`.

### Check conflicts

```powershell
Test-DevConflict
# or
Test-MergeConflict -CompareBranch develop
```

### Create merge branch (when conflicts exist)

```powershell
New-MergeBranch
# optional compare target
New-MergeBranch -CompareBranch develop
```

### Create PR

```powershell
New-PR -Target develop -IssueKey AL-123
New-PR -Target main -IssueKey AL-123 -Draft
```

`Target` accepted values: `develop` or `main`.

Template lookup order:

1. `.azuredevops/pull_request_template.<branchType>.md`
2. `.azuredevops/pull_request_template.md`
3. `.github/pull_request_template.md`
4. `%USERPROFILE%/.azuredevops/pull_request_template.md`

### Complete workflow

```powershell
Complete-Feature -IssueKey AL-123
Complete-Feature -IssueKey AL-123 -SkipTimer
```

### List your PRs

```powershell
Get-MyPRs
Get-MyPRs -Status completed
```

## Prerequisites

- `git`
- `az` (Azure CLI) configured for DevOps (`az devops configure`)
- Optional `jira` for integrated time logging

## References

- [Interactive usage](./INTERACTIVE_USAGE.md)
- [Time tracking](./TIME_TRACKING.md)
- [Module source](../modules/pr-workflow.psm1)
