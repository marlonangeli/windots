# windots

Dotfiles Windows para produtividade Dev/AI com Chezmoi + PowerShell: PowerShell, Windows Terminal, Git, Zed, Codex, MCP e automacoes idempotentes.

## Objetivo

Padronizar setup de ambiente Windows com foco em performance, reproducibilidade e seguranca.

## O que esta incluso

- PowerShell profile modular (modo full/clean)
- Windows Terminal (Catppuccin + JetBrains Mono Nerd Font)
- Git (config base e include local privado)
- Zed, Codex, Copilot (templates sanitizados)
- Configs em `.config` (jira/acli/opencode) com segregacao de segredos
- Scripts de bootstrap, instalacao e validacao
- Estrutura `.config/ai` para MCP/skills

## Requisitos

- PowerShell 7+
- Git
- [chezmoi](https://www.chezmoi.io/)
- opcional: `gh`, `bw`, `mise`

## Quick Start

```powershell
chezmoi init --apply <SEU_USER_GITHUB>/windots
```

### Desenvolvimento local

```powershell
chezmoi init --source .
chezmoi diff
chezmoi apply
```

## Segredos

Nunca versione tokens/chaves. Use Bitwarden CLI (`bw`) e arquivos locais privados.

Veja `docs/SECRETS.md`.

## Scripts

- `scripts/bootstrap.ps1`: setup principal pos-apply
- `scripts/install-tools.ps1`: instala toolchain
- `scripts/validate.ps1`: checks de seguranca e consistencia
- `scripts/link-ai-configs.ps1`: sincroniza configuracoes MCP/skills
- `scripts/export-current.ps1`: exporta estado atual para staging de templates

## Estrutura

```text
home/
  dot_config/
  dot_codex/
  dot_copilot/
  AppData/.../WindowsTerminal/settings.json.tmpl
  AppData/.../Zed/settings.json.tmpl
```

## Roadmap

- Espelhamento Azure DevOps
- VS Code profile sanitizado por camadas
- WSL por distro (Ubuntu/Arch)
- Fluxo de skills/MCP por host
