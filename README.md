# windots

Dotfiles Windows para produtividade Dev/AI com `chezmoi` + PowerShell, com foco em reprodutibilidade, segurança e automação idempotente.

## Escopo

- Perfil PowerShell modular (`full`/`clean`) em `home/dot_config/powershell/`
- Configs de terminal, Git, Zed, Codex, Copilot e ferramentas AI/MCP
- Scripts operacionais em `scripts/` para bootstrap, instalação, validação e migração de segredos

## Requisitos

- PowerShell 7+
- Git
- [chezmoi](https://www.chezmoi.io/)
- Opcional: `gh`, `bw`, `mise`

## Quick Start

```powershell
chezmoi init --apply <SEU_USER_GITHUB>/windots
pwsh ./scripts/bootstrap.ps1 -Mode full
pwsh ./scripts/validate.ps1
```

### One-command installer (remote)

```powershell
irm https://raw.githubusercontent.com/marlonangeli/windots/main/init.ps1 | iex
```

Esse comando baixa o `init.ps1`, instala dependências base, aplica o repo com `chezmoi`, executa bootstrap, validação e checks de segredos.

## Desenvolvimento local

```powershell
chezmoi init --source .
chezmoi diff
chezmoi apply
pwsh ./scripts/validate.ps1
```

## Scripts principais

- `scripts/bootstrap.ps1`: executa instalação opcional, `chezmoi apply` e sincronização AI
- `scripts/install-tools.ps1`: instala toolchain base via `winget`
- `scripts/validate.ps1`: valida arquivos obrigatórios e padrões de segredos
- `scripts/link-ai-configs.ps1`: copia/symlink de `home/dot_config/ai` para `~/.config/ai`
- `scripts/export-current.ps1`: exporta estado local para `_staging`
- `scripts/migrate-secrets.ps1`: checagem de legados (`.jira_access_token`, `tfstoken`)
- `scripts/check-secrets-deps.ps1`: auditoria de dependências e proteções para segredos

## Estrutura

```text
home/      # templates chezmoi (dotfiles e configs)
scripts/   # automações de setup/validação/migração
docs/      # documentação de setup, segredos, migração e decisões
```

## Documentação

- [Setup](docs/SETUP.md)
- [Segredos](docs/SECRETS.md)
- [Migração](docs/MIGRATION.md)
- [Decisões](docs/DECISIONS.md)
- [PowerShell profile docs](home/dot_config/powershell/docs/README.md)
