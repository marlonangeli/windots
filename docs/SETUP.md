# Setup

## 1) Run the installer

Canonical remote command:

```powershell
irm https://windots.ilegna.dev/install | iex
```

Local file execution:

```powershell
pwsh -NoProfile -File ./install.ps1
```

In interactive mode, installer execution shows the action menu:

- `INSTALL`
- `UPDATE`
- `RESTORE`
- `QUIT`

Use `-Action install -AutoApply` for full unattended flow.

In interactive mode, package-heavy modules can prompt for default package set vs specific package selection.

```powershell
pwsh -NoProfile -File ./install.ps1 -Action install -AutoApply -NoPrompt
```

## 2) Select source for testing

```powershell
# branch
pwsh -NoProfile -File ./install.ps1 -Branch feature/my-change -AutoApply

# commit/tag (overrides branch)
pwsh -NoProfile -File ./install.ps1 -Ref <sha-or-tag> -AutoApply

# local repository
pwsh -NoProfile -File ./install.ps1 -LocalRepoPath C:\src\windots -AutoApply
```

Optional guard:

```powershell
pwsh -NoProfile -File ./install.ps1 -RequireNonMain -Branch feature/my-change -AutoApply
```

## 3) Bootstrap manually

```powershell
pwsh ./scripts/bootstrap.ps1 -Mode full
```

Useful options:

- `-Mode clean`
- `-SkipInstall`
- `-SkipMise`
- `-Modules core,shell,terminal`
- `-IncludeSecretsChecks`

## 4) Day-2 commands

```powershell
pwsh ./scripts/windots.ps1 -Command update
pwsh ./scripts/windots.ps1 -Command apply
pwsh ./scripts/windots.ps1 -Command bootstrap -Mode clean
pwsh ./scripts/windots.ps1 -Command restore -RestoreConfigPath "$env:LOCALAPPDATA\windots\state\restore.json"
pwsh ./scripts/windots.ps1 -Command validate
```

## 5) Validate

```powershell
pwsh -NoProfile -File ./scripts/validate.ps1
pwsh -NoProfile -File ./scripts/validate-modules.ps1
pwsh -NoProfile -File ./tests/run.ps1
```

## 6) Module-owned utility scripts

- Profile shim:
  - `pwsh ./modules/shell/profile-shim.ps1 -Action status`
  - `pwsh ./modules/shell/profile-shim.ps1 -Action reset`
- AI config sync:
  - `pwsh ./modules/ai/link-configs.ps1`
  - `pwsh ./modules/ai/link-configs.ps1 -UseSymlink`
- Secrets:
  - `pwsh ./modules/secrets/migrate.ps1`
  - `pwsh ./modules/secrets/deps-check.ps1`

## 7) Winget behavior

`winget` installs/upgrades are mediated by `scripts/common/winget.ps1`.

- Source is forced to `winget`
- `msstore` certificate/source failures trigger automatic fallback
- Commands are logged and fail fast when retries are exhausted

Restore config contract and examples are documented in `docs/RESTORE.md`.
