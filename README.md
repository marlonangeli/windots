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
- Opcional: `gh`, `bw`, `mise`, `gum`

## Quick Start

```powershell
chezmoi init --apply <SEU_USER_GITHUB>/windots
pwsh ./scripts/bootstrap.ps1 -Mode full
pwsh ./scripts/validate.ps1
```

Fluxo seguro de atualização (recomendado):

```powershell
pwsh ./scripts/windots.ps1 -Command update
```

> Se quiser pular instalação/validação de toolchain `mise` no bootstrap:
> `pwsh ./scripts/bootstrap.ps1 -Mode full -SkipMise`

### One-command installer (remote)

```powershell
irm https://windots.ilegna.dev/install | iex
```

Esse comando baixa o `install.ps1`, instala dependências base e inicializa o source do `chezmoi`.
Para aplicar/configurar tudo automaticamente, use `-AutoApply`.

Se falhar por PATH recém-atualizado (ex.: `chezmoi not found`), rode sem reinstalar base:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/marlonangeli/windots/main/install.ps1"))) -SkipBaseInstall
```

Se ainda falhar, feche e abra um novo terminal e execute o comando acima novamente.

Se aparecer erro de bootstrap script não encontrado, o instalador resolve scripts pelo root esperado:
`$HOME/.local/share/chezmoi` (mesmo quando `chezmoi source-path` retorna `.../home`).

Por padrão, o `install.ps1` apenas inicializa/clona o source do `chezmoi` e mostra os próximos comandos para você rodar manualmente (`chezmoi apply`, bootstrap e validação).  
Para modo totalmente automático, use:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/marlonangeli/windots/main/install.ps1"))) -AutoApply
```

O instalador agora coleta dados interativamente (`user.name`, `user.email`, `github_username`, Azure opcional).  
Para execução sem prompts: `-NoPrompt`.
Para selecionar módulos específicos no auto-apply: `-Modules core,shell,terminal`.
Para instalar/testar a partir de branch/ref/local: `-Branch`, `-Ref`, `-LocalRepoPath`.

Exemplos:

```powershell
# branch específica
pwsh -NoProfile -File ./install.ps1 -Branch feature/install-refactor -AutoApply

# commit/tag específico (Ref sobrescreve Branch)
pwsh -NoProfile -File ./install.ps1 -Ref <sha-ou-tag> -AutoApply

# teste sem push usando repositório local
pwsh -NoProfile -File ./install.ps1 -LocalRepoPath C:\\src\\windots -AutoApply
```

## Desenvolvimento local

```powershell
chezmoi init --source .
chezmoi diff
chezmoi apply
pwsh ./scripts/validate.ps1
```

## Scripts principais

- `scripts/bootstrap.ps1`: delega para o runner de módulos (`full`/`clean`)
- `scripts/install.ps1`: instalador canônico (repo/branch/ref/local source)
- `scripts/install-from-repo.ps1`: alias de compatibilidade para `scripts/install.ps1`
- `scripts/run-modules.ps1`: resolve dependências e executa módulos em ordem determinística
- `scripts/install-tools.ps1`: instala toolchain base via `winget`
- `scripts/validate.ps1`: valida arquivos obrigatórios e padrões de segredos
- `scripts/validate-modules.ps1`: valida contrato do registry de módulos
- `scripts/windots.ps1`: wrapper para `update/apply/bootstrap/validate`
- `scripts/link-ai-configs.ps1`: copia/symlink de `home/dot_config/ai` para `~/.config/ai`
- `scripts/install-profile-shim.ps1`: cria perfil shim no caminho oficial do PowerShell apontando para `~/.config/powershell`
- `scripts/export-current.ps1`: exporta estado local para `_staging`
- `scripts/migrate-secrets.ps1`: checagem de legados (`.jira_access_token`, `tfstoken`)
- `scripts/check-secrets-deps.ps1`: auditoria de dependências e proteções para segredos

## Módulos atuais

- `core`: aplica estado declarativo com `chezmoi apply`
- `packages`: instala base via `install-tools.ps1`
- `shell`: instala profile shim do PowerShell
- `themes`: configura oh-my-posh e fonte
- `terminal`: valida presença do template/hook do Windows Terminal
- `ai`: sincroniza `~/.config/ai`
- `mise`: ativa PATH e instala toolchain declarada
- `secrets`: executa checks de migração/dependências de segredos
- `validate`: executa validação do repositório

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
tests/     # pester/integration/sandbox
docs/      # documentação de setup, segredos, migração e decisões
```

## Documentação

- [Setup](docs/SETUP.md)
- [Segredos](docs/SECRETS.md)
- [Migração](docs/MIGRATION.md)
- [Decisões](docs/DECISIONS.md)
- [PowerShell profile docs](home/dot_config/powershell/docs/README.md)
