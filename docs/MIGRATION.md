# Migration

## Origens comuns

- `~/.gitconfig`
- `~/.gitignore_global`
- `~/.codex/config.toml`
- `~/AppData/Roaming/Zed/settings.json`
- `~/Documents/PowerShell` e `~/.config/powershell`

## Processo recomendado

1. Exportar estado atual:

```powershell
pwsh ./scripts/export-current.ps1
```

2. Revisar `_staging/` e sanitizar segredos.
3. Converter arquivos para templates `*.tmpl` quando houver variação por host/usuário.
4. Mover para a estrutura final em `home/`.
5. Rodar validação:

```powershell
pwsh ./scripts/validate.ps1
```

## Migração de segredos legados

Antes de finalizar:

```powershell
pwsh ./scripts/migrate-secrets.ps1
```

Esse script verifica `.jira_access_token` e `tfstoken` em `.gitconfig`.

## Referências

- [Setup](./SETUP.md)
- [Secrets](./SECRETS.md)
