# Secrets

## Regras

- Nunca versionar tokens/chaves/senhas.
- Use Bitwarden CLI (`bw`) para recuperar segredos em runtime.
- Arquivos locais privados devem usar sufixo `.local.*`.

## Itens sensiveis comuns

- `~/.codex/auth.json`
- `~/.jira_access_token`
- tokens em `.gitconfig`
- `~/.ssh/id_*`
- credenciais em configs de editor/CLI

## Jira token

1. Revogar token antigo se estava em arquivo local.
2. Criar novo token no Jira.
3. Salvar no Bitwarden.
4. Injetar por env var no bootstrap quando necessario.
