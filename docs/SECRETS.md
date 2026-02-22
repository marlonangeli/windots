# Secrets

## Rules

- Never commit tokens, private keys, or passwords.
- Use external secret storage (for example, Bitwarden) for runtime retrieval.
- Keep local-only overrides outside tracked templates.
- For restore config, keep only environment variable names (`secretEnv`) and never raw secret values.
- Run validation before commit:

```powershell
pwsh -NoProfile -File ./scripts/validate.ps1
```

## Common sensitive paths

- `~/.codex/auth.json`
- `~/.jira_access_token` (legacy, avoid)
- `~/.ssh/id_*`
- credentials in `~/.gitconfig` (for example `tfstoken=`)

## Rotation and cleanup workflow

1. Run migration checks:

```powershell
pwsh ./modules/secrets/migrate.ps1
pwsh ./modules/secrets/deps-check.ps1
```

2. Revoke exposed credentials.
3. Create new credentials.
4. Store them in secret manager and inject at runtime via environment or local untracked files.

## Related files

- `scripts/validate.ps1`
- `modules/secrets/module.ps1`
- `modules/secrets/migrate.ps1`
- `modules/secrets/deps-check.ps1`
- `.gitignore`
