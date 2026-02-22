# Secrets

## Rules

- Never commit tokens, private keys, or passwords.
- Keep secrets in external stores (for example Bitwarden) and inject at runtime.
- Keep host-specific overrides outside tracked templates (`*.local.*`, private files, env vars).
- In restore config, store only environment variable names in `secretEnv`, never secret values.

Validate before commit:

```powershell
pwsh -NoProfile -File ./scripts/validate.ps1
```

## Sensitive Paths To Watch

- `~/.codex/auth.json`
- `~/.ssh/id_*`
- credential-bearing entries in `~/.gitconfig`

## Rotation and Cleanup Workflow

1. Run repository checks:

```powershell
pwsh ./modules/secrets/migrate.ps1
pwsh ./modules/secrets/deps-check.ps1
```

2. Revoke exposed credentials.
3. Create replacement credentials.
4. Store replacements in secret manager and reinject via environment/local untracked files.

## Related Files

- `scripts/validate.ps1`
- `modules/secrets/module.ps1`
- `modules/secrets/migrate.ps1`
- `modules/secrets/deps-check.ps1`
- `.gitignore`
