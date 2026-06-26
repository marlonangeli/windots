# ilegna manual

`ilegna` is the day-2 workflow CLI for this repository. It stays outside the bootstrap path and focuses on small, repeatable developer actions.

The command shape is stable:

```powershell
ilegna <resource> <command> [args]
il <resource> <command> [args]
```

`il` is the profile alias.

## Core loop

A normal task can be driven from one command family:

```powershell
ilegna task start AL-1541 implement csv import --type feat --base develop --cd
ilegna task show
ilegna git status
ilegna task pr
ilegna task pipeline trigger --dry-run
ilegna task done --log
```

What this does:

1. creates a deterministic branch name, for example `feat/AL-1541-implement-csv-import`;
2. creates a worktree from the selected base;
3. starts a local Jira timer;
4. stores local task metadata under `%LOCALAPPDATA%\ilegna\tasks`;
5. reuses the task metadata for PR title/base and pipeline branch selection.

Use `--no-worktree` when you want the branch in the current checkout.
Use `--no-timer` when the task should not touch Jira time tracking.

## Worktrees

```powershell
ilegna wt new feat/my-change --base develop --cd
ilegna wt list
ilegna wt status
ilegna wt open feat/my-change
ilegna wt remove feat/my-change
ilegna wt prune
```

Default worktree location:

- bare-backed repository: next to the bare repo;
- normal repository: `.worktrees/<branch-name>`.

Branch names are converted to safe directory names by replacing `/` and other path separators with `-`.

## Chezmoi capture

Use `cm` when you changed a local config and want to capture it back into the repo.

```powershell
ilegna cm capture $PROFILE --edit
ilegna cm capture ~/.gitconfig.local --dry-run
ilegna cm capture ~/.config/starship.toml --apply
ilegna cm refresh
ilegna cm diff
ilegna cm status
ilegna cm unmanaged
ilegna cm source
```

Command behavior:

- `capture <path...>` runs `chezmoi add` for each target and then shows `chezmoi diff`.
- `capture --edit` opens the source file/template after adding it.
- `capture --apply` applies after the diff.
- `capture --dry-run` prints the intended commands without changing chezmoi state.
- `refresh` runs `chezmoi re-add`, useful after editing managed target files directly.

Recommended flow:

```powershell
ilegna cm capture <changed-file> --edit
ilegna cm diff
pwsh ./scripts/validate.ps1
```

## Git helpers

```powershell
ilegna git status
ilegna git sync
ilegna git sync --pull --tags
ilegna git publish
ilegna git publish --pr
ilegna git clean-merged --base develop --dry-run
```

`publish --pr` pushes the current branch and delegates PR creation to `ilegna task pr`, so task metadata is reused when present.

## Pull requests

```powershell
ilegna pr new
ilegna pr new --base develop --ready
ilegna pr list --status active
ilegna pr view 123 --open
ilegna pr checkout 123
```

`pr new` targets Azure DevOps repositories through `az repos pr create`. By default, PRs are drafts unless `--ready` is passed.

## Pipelines and releases

```powershell
ilegna pipeline active
ilegna pipeline trigger --dry-run
ilegna pipeline trigger --id 42 --branch feat/AL-1541-implement-csv-import
ilegna pipeline list
ilegna pipeline watch 7995
ilegna pipeline approvals --run-id 7995 --stage Deploy_Dev
ilegna pipeline complete --run-id 7995 --stage Deploy_Dev --dry-run
```

The command supports:

- Azure DevOps YAML pipelines;
- classic release approvals;
- GitHub Actions listing/watch/open fallback when the repository remote is GitHub.

## Jira time tracking

```powershell
ilegna jira mine
ilegna jira start AL-1541 "implement csv import"
ilegna jira show
ilegna jira stop --log
ilegna jira worklog AL-1541 30m "implementation"
```

Durations must use Jira-style units: `30m`, `1h`, `1h 30m`, `2d`, `1w 2d 3h 30m`.

The timer file is local only and is stored under `%LOCALAPPDATA%\ilegna\work-timer.json`.

## Local task metadata

`ilegna task` stores only workflow metadata:

```json
{
  "issue": "AL-1541",
  "summary": "implement csv import",
  "branch": "feat/AL-1541-implement-csv-import",
  "base": "develop",
  "worktreePath": "C:\\src\\repo\\.worktrees\\feat-AL-1541-implement-csv-import",
  "createdAt": "2026-06-26T12:00:00.0000000-03:00"
}
```

No Jira credentials, GitHub secrets, Azure secrets, or SSH material are stored by `ilegna`.

## Doctor

```powershell
ilegna doctor
```

Checks whether local workflow tools are available: `git`, `chezmoi`, `mise`, `starship`, `zoxide`, `gh`, `az`, `jira`, `codex`, `rtk`, and `opencode`.

## Design rules

- Commands are small and composable.
- Destructive actions need explicit commands or `--force`.
- Dry-run is preferred for pipeline approvals, branch cleanup, and new capture flows.
- External CLIs stay the source of truth; `ilegna` only adds project-specific glue.
