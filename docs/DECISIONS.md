# Decisions

## Estratégia de configuração

- Base: `chezmoi` para templates e aplicação declarativa.
- Automação: scripts PowerShell em `scripts/` para bootstrap, validação e migração.
- Perfil shell: modular em `home/dot_config/powershell/modules/`.
- Toolchain CLI: preferência por `mise` (winget focado em sistema/GUI e exceções).

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
