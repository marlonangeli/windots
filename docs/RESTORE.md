# Restore

`restore` rebuilds a machine from a JSON config plus environment-backed secret references.

Default config path:

- `%LOCALAPPDATA%\windots\state\restore.json`

## Run

```powershell
pwsh ./scripts/windots.ps1 -Command restore
```

Explicit config path:

```powershell
pwsh ./scripts/windots.ps1 -Command restore -RestoreConfigPath "C:\path\to\restore.json"
```

## Config Shape

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

## Field Notes

- `installer`: same source/mode choices you would pass to `install.ps1`.
- `chezmoiData`: non-secret values used to hydrate `CHEZMOI_*` runtime data.
- `secretEnv`: environment variable names to read secret values from at runtime.

## Security Notes

- Do not put raw secrets in restore JSON.
- Keep restore files private and machine-scoped when possible.
- Prefer user-level environment variables or secret manager injection before running restore.
