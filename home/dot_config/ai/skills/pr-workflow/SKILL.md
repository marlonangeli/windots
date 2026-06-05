---
name: pr-workflow
description: Use when creating, reviewing, or updating pull requests with gh, az repos, or the ilegna pr commands.
---

# PR Workflow

Use the smallest branch and PR flow that works for the repository.

Checklist:

- Inspect `git status -sb` before changing branches.
- Prefer `ilegna wt new <branch> --base <base>` for parallel work.
- Prefer `ilegna pr new --base <target>` to create PRs.
- Include validation output in the PR description when available.
- Do not force-push or rewrite history unless explicitly requested.
