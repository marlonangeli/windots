# PR Workflow - Azure DevOps

## 🎯 Fluxo Completo

```
main (produção) ──┐
                  │
                  ├─→ feat/AL-123-user-auth ──→ PR → develop
                  │                              │
                  └──────────────────────────────┴─→ PR → main
```

**Regras:**
1. Tudo parte da `main` (estável e produção)
2. Branch para feature/fix (`feat/AL-123-feature-name`)
3. PR para `develop` primeiro
4. Após merge em develop, PR da branch original para `main`

---

## 📦 Comandos

### 1. New-Feature
Cria nova branch a partir da main

```powershell
New-Feature "user-auth" -Type feat -IssueKey AL-123
New-Feature "login-bug" -Type fix -IssueKey AL-124
New-Feature "refactor-db" -Type refactor
New-Feature "docs-api" -Type docs -IssueKey AL-125 -Worktree
```

**Parâmetros:**
- `Name` (obrigatório): Nome da feature
- `Type`: feat, fix, hotfix, refactor, docs, test, chore (padrão: feat)
- `IssueKey`: Jira issue key (ex: AL-123)
- `Worktree`: Cria como worktree em vez de branch normal

**Aliases:** `nf`

**Resultado:**
- Branch criada: `feat/AL-123-user-auth`
- Checkout automático
- Timer iniciado (se `IssueKey` fornecido)

---

### 2. Test-DevConflict
Verifica conflitos com develop antes de criar PR

```powershell
Test-DevConflict
```

**Output:**
- ✅ Sem conflitos → Pode criar PR
- ⚠️ Conflitos detectados → Criar merge branch

---

### 3. New-MergeBranch
Cria branch temporária de merge com develop (quando há conflitos)

```powershell
New-MergeBranch
```

**Resultado:**
- Branch criada: `feat/AL-123-user-auth-merge-dev`
- Pull de `origin/develop`
- Resolve conflitos manualmente
- Usa essa branch para PR

---

### 4. New-PR
Cria Pull Request para develop ou main

```powershell
New-PR -Target develop -IssueKey AL-123
New-PR -Target develop -Title "Add OAuth support" -IssueKey AL-123
New-PR -Target main -IssueKey AL-123
New-PR -Target develop -IssueKey AL-123 -Draft  # PR como draft
```

**Parâmetros:**
- `Target` (obrigatório): `develop` ou `main`
- `Title`: Título do PR (auto-gerado se não fornecido)
- `IssueKey`: Jira issue key
- `Draft`: Criar como draft PR

**Aliases:** `npr`

**Formato do Título:**
- Com IssueKey: `AL-123: Add user authentication`
- Sem IssueKey: `Add user authentication`

**Template de PR:**
Busca template em:
1. `.\.azuredevops\pull_request_template.md` (repositório)
2. `$env:USERPROFILE\.azuredevops\pull_request_template.md` (global)

---

### 5. Complete-Feature
Workflow completo automático

```powershell
Complete-Feature -IssueKey AL-123
Complete-Feature -IssueKey AL-123 -SkipTimer
```

**Executa:**
1. Verifica conflitos com develop
2. Cria PR para develop
3. Para timer e loga tempo no Jira

**Aliases:** `cf`

---

### 6. Get-MyPRs
Lista seus Pull Requests ativos

```powershell
Get-MyPRs
```

**Aliases:** `prs`

---

## 🔄 Workflows Completos

### Workflow 1: Feature sem Conflitos
```powershell
# 1. Criar feature
New-Feature "oauth-integration" -Type feat -IssueKey AL-123
# Branch: feat/AL-123-oauth-integration
# Timer iniciado

# 2. Desenvolver
ga .
gc "feat: add OAuth2 support"
gp -u origin feat/AL-123-oauth-integration

# 3. Verificar conflitos
Test-DevConflict
# ✅ No conflicts with develop

# 4. Criar PR para develop
New-PR -Target develop -IssueKey AL-123
# PR criado: AL-123: oauth integration

# 5. Aguardar aprovação e merge

# 6. Criar PR para main (com branch original)
git checkout feat/AL-123-oauth-integration
New-PR -Target main -IssueKey AL-123
```

### Workflow 2: Feature COM Conflitos
```powershell
# 1-2. Mesmo que Workflow 1

# 3. Verificar conflitos
Test-DevConflict
# ⚠️  CONFLICTS DETECTED with develop!

# 4. Criar merge branch
New-MergeBranch
# Branch: feat/AL-123-oauth-integration-merge-dev
# Pull de develop executado

# 5. Resolver conflitos
# ... editar arquivos conflitantes ...
ga .
gc "resolve merge conflicts with develop"
gp -u origin feat/AL-123-oauth-integration-merge-dev

# 6. Criar PR com merge branch
New-PR -Target develop -IssueKey AL-123
# PR usa branch: feat/AL-123-oauth-integration-merge-dev

# 7. Após merge, PR para main com branch ORIGINAL
git checkout feat/AL-123-oauth-integration
New-PR -Target main -IssueKey AL-123
```

### Workflow 3: Automático (Complete-Feature)
```powershell
# 1. Criar e desenvolver
nf "payment-gateway" -Type feat -IssueKey AL-124
# ... desenvolvimento ...
ga .
gc "feat: integrate payment gateway"
gp

# 2. Executar workflow completo
cf -IssueKey AL-124
# ✅ Conflitos verificados
# ✅ PR criado para develop
# ✅ Timer parado e logado

# 3. Após merge em develop, PR para main
git checkout feat/AL-124-payment-gateway
npr -Target main -IssueKey AL-124
```

---

## 📝 Templates de PR

### Template Repositório
`.azuredevops/pull_request_template.md`:

```markdown
## 📋 Descrição
<!-- Descreva as mudanças -->

## 🔗 Issue Relacionada
- Closes AL-XXX

## ✅ Checklist
- [ ] Código testado
- [ ] Testes unitários adicionados/atualizados
- [ ] Documentação atualizada
- [ ] Code review realizado
- [ ] Build passa

## 🧪 Como Testar
1. ...
2. ...

## 📸 Screenshots (se aplicável)

## 🚀 Impacto
- [ ] Breaking change
- [ ] Requer atualização de ambiente
- [ ] Requer migração de dados
```

### Template Global
`~/.azuredevops/pull_request_template.md` (mesmo formato)

---

## 🎯 Convenções

### Nomes de Branch
```
feat/AL-123-feature-name
fix/AL-124-bug-description
hotfix/AL-125-critical-fix
refactor/AL-126-code-cleanup
docs/AL-127-api-docs
test/AL-128-unit-tests
chore/AL-129-dependency-update
```

### Mensagens de Commit
Seguir [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add user authentication
fix: resolve memory leak in auth service
docs: update API documentation
refactor: simplify database queries
test: add unit tests for auth module
chore: update dependencies
```

---

## 🔧 Configuração Azure CLI

### Instalação
```powershell
winget install Microsoft.AzureCLI
```

### Login
```powershell
az login
```

### Configurar Repositório Padrão
```powershell
az repos show
az devops configure --defaults organization=https://dev.azure.com/yourorg project=YourProject
```

---

## 💡 Dicas

### ✅ Boas Práticas
- Sempre puxar `main` antes de criar feature
- Use `IssueKey` em todos os comandos
- Verifique conflitos antes de criar PR
- Mantenha PRs pequenos e focados
- Code review antes de aprovar
- Delete branches após merge

### ⚠️ Cuidados
- Nunca force push em `main` ou `develop`
- Não merge PR sem aprovação
- Sempre teste localmente antes de PR
- Não commite em `main` diretamente

---

## 🐛 Troubleshooting

### Azure CLI não encontrado
```powershell
# Instalar
winget install Microsoft.AzureCLI

# Verificar
az --version
```

### PR falha ao criar
```powershell
# Verificar login
az account show

# Re-autenticar
az login

# Verificar permissões
az repos pr list
```

### Template não encontrado
```powershell
# Criar global
mkdir ~/.azuredevops
# Criar arquivo pull_request_template.md
```

### Branch não existe no remoto
```powershell
# Push da branch primeiro
git push -u origin nome-da-branch

# Depois criar PR
New-PR -Target develop
```
