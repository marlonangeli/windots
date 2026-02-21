# Secrets

## Regras

- Nunca versionar tokens, chaves ou senhas.
- Usar Bitwarden CLI (`bw`) para recuperação em runtime quando aplicável.
- Manter overrides locais privados como `.local.*`.
- Validar sempre antes de commit: `pwsh ./scripts/validate.ps1`.
- Em mudanças na orquestração de módulos, validar também: `pwsh ./scripts/validate-modules.ps1`.

## Itens sensíveis comuns

- `~/.codex/auth.json`
- `~/.jira_access_token` (legado; evitar)
- `~/.ssh/id_*`
- credenciais em `.gitconfig` (ex.: `tfstoken=`)
- tokens em configs de editor/CLI

## Fluxo recomendado de migração/rotação

1. Executar `pwsh ./scripts/migrate-secrets.ps1` para detectar legados.
2. Executar `pwsh ./scripts/check-secrets-deps.ps1` para validar dependências e proteções do repositório.
3. Revogar credenciais expostas.
4. Gerar novas credenciais.
5. Salvar no cofre (Bitwarden) e injetar por variável de ambiente/local privado.

## Referências

- [Validação automática](../scripts/validate.ps1)
- [Validação de módulos](../scripts/validate-modules.ps1)
- [Migração de segredos](../scripts/migrate-secrets.ps1)
- [Dependências de segredos](../scripts/check-secrets-deps.ps1)
- [Gitignore do repositório](../.gitignore)
