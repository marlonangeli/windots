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

> Se quiser pular instalação/validação de toolchain `mise` no bootstrap:
> `pwsh ./scripts/bootstrap.ps1 -Mode full -SkipMise`

### One-command installer (remote)

```powershell
irm https://raw.githubusercontent.com/marlonangeli/windots/main/init.ps1 | iex
```

Esse comando baixa o `init.ps1`, instala dependências base, aplica o repo com `chezmoi`, executa bootstrap, validação e checks de segredos.

Se falhar por PATH recém-atualizado (ex.: `chezmoi not found`), rode sem reinstalar base:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/marlonangeli/windots/main/init.ps1"))) -SkipBaseInstall
```

Se ainda falhar, feche e abra um novo terminal e execute o comando acima novamente.

Por padrão, o `init.ps1` apenas inicializa/clona o source do `chezmoi` e mostra os próximos comandos para você rodar manualmente (`chezmoi apply`, bootstrap e validação).  
Para modo totalmente automático, use:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/marlonangeli/windots/main/init.ps1"))) -AutoApply
```

O instalador agora coleta dados interativamente (`user.name`, `user.email`, `github_username`, Azure opcional).  
Para execução sem prompts: `-NoPrompt`.

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
- `scripts/install-profile-shim.ps1`: cria perfil shim no caminho oficial do PowerShell apontando para `~/.config/powershell`
- `scripts/export-current.ps1`: exporta estado local para `_staging`
- `scripts/migrate-secrets.ps1`: checagem de legados (`.jira_access_token`, `tfstoken`)
- `scripts/check-secrets-deps.ps1`: auditoria de dependências e proteções para segredos

## Pós-Update automático

- `chezmoi update` já executa um hook em `home/.chezmoiscripts/run_after_*` que replica `~/.config/windows-terminal/settings.json`
  para `~/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json`.
- Isso garante que o template em `home/dot_config/windows-terminal/settings.json.tmpl` seja refletido no Windows Terminal Stable.

## Toolchain com mise

- `mise` é o gerenciador preferencial para CLIs de desenvolvimento no perfil:
  - `node`, `bun`, `pnpm`, `python`, `go`, `rust`, `dotnet`
  - `gh`, `codex`, `ripgrep`, `fd`, `bat`, `zoxide`, `starship`
- `home/dot_config/mise/config.toml.tmpl` é a fonte declarativa.
- `bootstrap` roda `mise install`, `mise doctor` e `mise ls`.
- `GitHub.Copilot` permanece via `winget` (se disponível).

## Oh My Posh

- `bootstrap` executa `scripts/setup-oh-my-posh.ps1` para:
  - garantir tema `catppuccin_mocha.omp.json` em `$env:POSH_THEMES_PATH`
  - instalar/garantir Nerd Font JetBrains Mono (fallback via winget)
- O profile PowerShell usa fallback de `POSH_THEMES_PATH` para `%LOCALAPPDATA%\Programs\oh-my-posh\themes`.

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
