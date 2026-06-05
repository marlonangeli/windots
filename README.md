# windots

```text
██╗    ██╗██╗███╗   ██╗██████╗  ██████╗ ████████╗███████╗
██║    ██║██║████╗  ██║██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝
██║ █╗ ██║██║██╔██╗ ██║██║  ██║██║   ██║   ██║   ███████╗
██║███╗██║██║██║╚██╗██║██║  ██║██║   ██║   ██║   ╚════██║
╚███╔███╔╝██║██║ ╚████║██████╔╝╚██████╔╝   ██║   ███████║
 ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═════╝  ╚═════╝    ╚═╝   ╚══════╝
```

Windows dotfiles with `chezmoi`, PowerShell, `mise`, Starship, Zoxide, AI configs, and one small workflow CLI: `ilegna`.

The goal is simple: make a Windows dev machine useful fast, keep the repo easy to change, and leave the fun day-to-day commands outside the bootstrap path.

## First Run

Remote install:

```powershell
irm https://windots.ilegna.dev/install | iex
```

Local development from this repo:

```powershell
chezmoi init --source .
chezmoi apply
pwsh ./scripts/bootstrap.ps1 -Mode full
pwsh ./scripts/validate.ps1
```

Quick local link:

```powershell
pwsh ./scripts/link.ps1 -Apply
```

This sets `WINDOTS_REPO_ROOT` for the profile and applies dotfiles using the local repository as the `chezmoi` source.

## Daily Commands

```powershell
pwsh ./scripts/bootstrap.ps1 -Mode clean -SkipInstall
pwsh ./scripts/validate.ps1
pwsh ./scripts/doctor.ps1
```

`ilegna` is the workflow CLI:

```powershell
ilegna wt new feat/fun-cli --base main
ilegna wt list
ilegna pr new --base develop --draft
ilegna pipeline list
ilegna jira start ABC-123 "small task"
ilegna jira stop --log
ilegna config backup
ilegna config list
ilegna config restore latest --items ssh
```

Direct script usage also works:

```powershell
pwsh ./scripts/ilegna.ps1 wt new feat/fun-cli --base main
```

## Local Config Backup

Before applying windots on a machine with existing custom config:

```powershell
ilegna config backup
```

Backups are local only and are written to `%LOCALAPPDATA%\windots\backups\configs`.

Included by default:

- `.gitconfig`, `.gitconfig.local`, `.gitignore_global`
- `.ssh/config`, `.ssh/config.local`, `.ssh/known_hosts`, `.ssh/config.d/`

Restore a specific backup:

```powershell
ilegna config list
ilegna config restore 20260605-153000
ilegna config restore latest --items git
ilegna config restore latest --items ssh
```

Restore asks before overwriting existing files and saves pre-restore copies. Use `--force` only when you intentionally want to overwrite without prompts.

Keep personal Git aliases/scripts in `~/.gitconfig.local`; the managed `.gitconfig` includes it and chezmoi does not manage that local file.

## What Gets Managed

- `home/`: chezmoi source for files under `%USERPROFILE%`.
- `home/dot_config/powershell/profile.d/`: fast modular PowerShell profile.
- `home/dot_config/mise/config.toml.tmpl`: toolchain source of truth.
- `home/dot_config/starship.toml`: minimal prompt.
- `home/dot_gitconfig.tmpl`: Git defaults with `delta`, `rerere`, `pull.ff only`, and `zdiff3`.
- `home/dot_config/windows-terminal/settings.json.tmpl`: PowerShell, Arch WSL, and Arch Zellij profiles.
- `home/dot_wslconfig`: WSL defaults tuned for Docker/WSL dev.
- `home/dot_config/ai/`: shared AI context, skills, and MCP references.
- `home/dot_codex/config.toml.tmpl`: Codex config.
- `home/dot_config/opencode/opencode.json.tmpl`: OpenCode config.

## PowerShell Profile

Modes:

```powershell
pmode
pclean
pfull
reload
```

Startup profiling:

```powershell
$env:WINDOTS_PROFILE_DEBUG = "1"
pwsh
```

`mise` uses shims/PATH by default. Prompt-time activation only runs when requested:

```powershell
$env:MISE_ACTIVATE = "1"
pwsh
```

## Module Bootstrap

The bootstrap remains module-driven for install/setup work:

```text
install.ps1
  -> scripts/windots.ps1
  -> scripts/bootstrap.ps1
      -> scripts/run-modules.ps1
          -> modules/<name>/module.ps1
```

Default modules:

- `core`: base tools and `chezmoi apply`.
- `shell`: PowerShell profile shim and shell basics.
- `mise`: trusts config and installs configured tools.
- `packages`: optional GUI/CLI packages.
- `development`: developer runtimes.
- `themes`: Starship/font checks.
- `terminal`: Windows Terminal templates.
- `ai`: AI config sync.

## Validation

```powershell
pwsh ./scripts/validate.ps1
pwsh ./scripts/validate-modules.ps1
pwsh ./tests/run.ps1
pwsh ./tests/run.ps1 -IncludeIntegration
```

## Docs

- [Setup](docs/SETUP.md)
- [Restore](docs/RESTORE.md)
- [Decisions](docs/DECISIONS.md)
- [Secrets](docs/SECRETS.md)
