# Decisions

## Estratégia de configuração

- Base: `chezmoi` para templates e aplicação declarativa.
- Automação: scripts PowerShell em `scripts/` para bootstrap, validação e migração.
- Orquestração: execução por módulos com registry declarativo em `scripts/modules/module-registry.ps1`.
- Perfil shell: modular em `home/dot_config/powershell/modules/`.
- Toolchain CLI: preferência por `mise` (winget focado em sistema/GUI e exceções).

## Contratos estáveis

- `install.ps1` é o entrypoint remoto canônico e delega para `scripts/install.ps1`.
- `scripts/bootstrap.ps1` mantém interface principal e delega para `scripts/run-modules.ps1`.
- `scripts/validate.ps1` continua gate obrigatório local/CI.

## Modelo de módulos

- Cada módulo declara dependências, categoria e entrypoint.
- Resolução de ordem é determinística e validada por `scripts/validate-modules.ps1`.
- Fluxo interativo usa `Read-Host` como baseline; `gum` é opcional para UX melhor.

## Segurança

- Segredos não versionados no Git.
- Verificações automáticas em `scripts/validate.ps1`.
- Migração de legados em `scripts/migrate-secrets.ps1`.
- Preferência por cofre externo (Bitwarden CLI) e arquivos locais privados.

## Escopo atual

- PowerShell, Windows Terminal, Git, Zed
- Codex/Copilot/MCP em `home/dot_config/ai/`
- Configurações selecionadas em `.config` (`jira`, `mise`, `opencode`)

## Referências

- [README](../README.md)
- [Setup](./SETUP.md)
- [PowerShell docs](../home/dot_config/powershell/docs/README.md)
