# Migration

## Origem sugerida

- `~/Documents/PowerShell`
- `~/.gitconfig`
- `~/.gitignore_global`
- `~/.codex/config.toml`
- `~/.copilot/config.json`
- `~/.config/*` selecionado
- `~/AppData/.../WindowsTerminal/settings.json`
- `~/AppData/Roaming/Zed/settings.json`

## Processo

1. Exportar com `scripts/export-current.ps1`.
2. Sanitizar segredos.
3. Converter para templates `.tmpl` quando houver dado por usuario/host.
4. Validar com `scripts/validate.ps1`.
