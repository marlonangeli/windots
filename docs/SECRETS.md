# Secrets

## Regras

- Nunca versionar tokens, chaves ou senhas.
- Usar Bitwarden CLI (`bw`) para recuperação em runtime quando aplicável.
- Manter overrides locais privados como `.local.*`.
- Validar sempre antes de commit: `pwsh ./scripts/validate.ps1`.

## Itens sensíveis comuns

- `~/.codex/auth.json`
- `~/.jira_access_token` (legado; evitar)
- `~/.ssh/id_*`
- credenciais em `.gitconfig` (ex.: `tfstoken=`)
- tokens em configs de editor/CLI

## Fluxo recomendado de migração/rotação

1. Executar `pwsh ./scripts/migrate-secrets.ps1` para detectar legados.
2. Revogar credenciais expostas.
3. Gerar novas credenciais.
4. Salvar no cofre (Bitwarden) e injetar por variável de ambiente/local privado.

## Referências

- [Validação automática](../scripts/validate.ps1)
- [Migração de segredos](../scripts/migrate-secrets.ps1)
- [Gitignore do repositório](../.gitignore)
