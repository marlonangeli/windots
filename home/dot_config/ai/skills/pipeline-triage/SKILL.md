---
name: pipeline-triage
description: Use when investigating CI/CD pipeline failures, GitHub Actions runs, Azure Pipelines runs, or ilegna pipeline commands.
---

# Pipeline Triage

Start with the failing job and preserve the first real error.

Workflow:

- Use `ilegna pipeline list` or the platform CLI to find the failing run.
- Read logs around the first failing command, not only the final summary.
- Separate environment failures from code failures.
- Reproduce locally with the closest documented command.
- Report the minimal fix and the command used to verify it.
