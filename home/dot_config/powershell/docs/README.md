# PowerShell Profile

The profile is a small loader plus explicit scripts in `profile.d`.

Modes:

- `full`: shell basics, prompt, git/dev/AI helpers, and the `ilegna` CLI shim.
- `clean`: shell basics, prompt, aliases, and the `ilegna` CLI shim only.

Commands:

```powershell
pmode
pclean
pfull
reload
```

Starship is the default prompt when the cached init script exists; otherwise the profile falls back to a plain PowerShell prompt.

Debug startup time:

```powershell
$env:WINDOTS_PROFILE_DEBUG = "1"
pwsh
```

Layout:

```text
~/.config/powershell/
  Microsoft.PowerShell_profile.ps1
  profile.d/
    00-core.ps1
    10-env.ps1
    20-path.ps1
    30-prompt.ps1
    40-aliases.ps1
    50-git.ps1
    60-dev.ps1
    70-ai.ps1
    80-ilegna.ps1
```

Workflow commands live in `scripts/ilegna.ps1` instead of large profile modules:

```powershell
ilegna wt new feat/fun-cli --base main
ilegna pr new
ilegna pipeline list
ilegna jira start ABC-123 "small task"
```
