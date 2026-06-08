---
name: jira-worklog
description: Use when working with Jira issues, Jira worklogs, or ilegna jira start/show/stop commands.
---

# Jira Worklog

Keep Jira updates short and useful.

Guidelines:

- Use issue keys in branch names when the repository expects it.
- Start timers with `ilegna jira start ISSUE-123 "short task"`.
- Use `ilegna jira show` before stopping a timer.
- Use `ilegna jira stop --log` only when the Jira CLI is configured and the user wants a worklog entry.
