# Restore

`windots restore` rebuilds the machine using a JSON config plus environment-backed secrets.

Default config path:

- `%LOCALAPPDATA%\windots\state\restore.json`

## Run

```powershell
pwsh ./scripts/windots.ps1 -Command restore
```

Or with an explicit file:

```powershell
pwsh ./scripts/windots.ps1 -Command restore -RestoreConfigPath "C:\path\to\restore.json"
```

## Config Example

```json
{
  "installer": {
    "repo": "marlonangeli/windots",
    "branch": "main",
    "mode": "full",
    "modules": ["core", "shell", "development", "terminal"],
    "skipBaseInstall": false,
    "useSymlinkAI": false,
    "skipSecretsChecks": false
  },
  "chezmoiData": {
    "name": "Marlon",
    "github_username": "marlon"
  },
  "secretEnv": {
    "email": "WINDOTS_EMAIL",
    "azure_org": "WINDOTS_AZURE_ORG",
    "azure_project": "WINDOTS_AZURE_PROJECT"
  }
}
```

`secretEnv` values are environment variable names. The restore flow reads each variable and sets the corresponding `CHEZMOI_*` process environment value.

Do not store raw secrets in this JSON file.
