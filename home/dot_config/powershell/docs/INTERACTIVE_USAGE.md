# Interactive PowerShell Functions Guide

## Overview

Todos os módulos principais agora suportam **modo interativo** com:
- ✅ Comment-based help para autocomplete
- ✅ Prompts interativos quando parâmetros não são fornecidos
- ✅ Validação de entrada
- ✅ Error handling robusto
- ✅ Verbos aprovados do PowerShell (sem warnings do PSScriptAnalyzer)

## Como Usar

### Modo Direto (com parâmetros)
```powershell
New-Feature -Name "authentication" -Type "feat" -IssueKey "AL-1234"
Start-Work -IssueKey "AL-1234" -Description "Working on auth"
New-PR -Target "develop" -Title "Add authentication"
```

### Modo Interativo (sem parâmetros)
```powershell
# Simplesmente chame a função sem parâmetros
New-Feature
# Você será guiado com prompts interativos

Start-Work
# Prompts para issue key e descrição

New-PR
# Seleção de target branch e configuração
```

### Usando Ajuda Built-in
```powershell
# Ver ajuda completa
Get-Help New-Feature -Full

# Ver exemplos
Get-Help Start-Work -Examples

# Ver parâmetros
Get-Help New-PR -Parameter *

# Autocomplete funciona com Tab
New-Feature -<TAB>  # Lista todos os parâmetros
```

## Módulos Refatorados

### 1. Worktrees (worktrees.ps1)

**Mudanças:**
- ✅ Verbos aprovados: `Get-Worktree`, `New-Worktree`, `Remove-Worktree`, etc.
- ✅ Aliases mantidos para compatibilidade: `gwt`, `gwtn`, `gwtr`
- ✅ Modo interativo em todas as funções
- ✅ Comment-based help completo

**Funções:**
- `Get-Worktree` - Lista worktrees (alias: `gwt`)
- `New-Worktree` - Cria worktree com prompts (alias: `gwtn`)
- `Remove-Worktree` - Remove com validação (alias: `gwtr`)
- `Open-Worktree` - Abre em editor (alias: `gwto`)
- `Get-WorktreeStatus` - Status detalhado (alias: `gwts`)
- `Switch-Worktree` - Navega entre worktrees (alias: `gwtw`)
- `Clear-Worktree` - Limpa stale worktrees
- `New-WorktreeAI` - Cria com contexto AI (alias: `gwt-ai`)

**Exemplo Interativo:**
```powershell
# Criar worktree interativamente
New-Worktree -Interactive

# Ou simplesmente
New-Worktree
# Prompt: Branch name? feature-auth
# Prompt: Base branch? 1) main 2) develop 3) master 4) Other...

# Remover com seleção
Remove-Worktree
# Lista worktrees disponíveis com números
# Prompt: Select worktree to remove (1-5)?
```

### 2. Time Tracking (time-tracker.ps1)

**Mudanças:**
- ✅ Confirmação antes de logar no Jira (previne logs acidentais)
- ✅ Validação de issue key format
- ✅ Modo interativo com prompts
- ✅ Nova função: `Reset-Work`

**Funções:**
- `Start-Work` - Inicia timer (alias: `ws`)
- `Stop-Work` - Para e loga no Jira (alias: `we`)
- `Show-Work` - Mostra status (alias: `wt`)
- `Reset-Work` - Reseta sem logar

**Exemplo Interativo:**
```powershell
# Iniciar trabalho
Start-Work
# Prompt: Jira issue key? AL-1234
# Prompt: Description? Implementing OAuth

# Parar e logar
Stop-Work
# Mostra tempo decorrido
# Prompt: Log to Jira? (y/n) [default: y]

# Ver status atual
Show-Work
# ⏱️  Current Time: 02:15:30
# 📋 Issue: AL-1234
# 📊 Jira format: 2h 15m
```

### 3. PR Workflow (pr-workflow.ps1)

**Mudanças:**
- ✅ Modo interativo completo
- ✅ Detecção automática de issue key do branch name
- ✅ Validação de Azure CLI
- ✅ Suporte a múltiplos templates
- ✅ Error handling melhorado

**Funções:**
- `New-Feature` - Cria feature branch (alias: `nf`)
- `Test-DevConflict` - Verifica conflitos
- `New-MergeBranch` - Cria branch de merge
- `New-PR` - Cria Pull Request (alias: `npr`)
- `Complete-Feature` - Workflow completo (alias: `cf`)
- `Get-MyPRs` - Lista PRs (alias: `prs`)

**Exemplo Interativo:**
```powershell
# Criar feature
New-Feature -Interactive
# Prompt: Feature name? user-authentication
# Prompt: Branch types: 1) feat 2) fix 3) hotfix...
# Prompt: Jira issue key? AL-1234
# Prompt: Create as worktree? (y/n)
# Prompt: Start work timer? (y/n)

# Criar PR
New-PR -Interactive
# Current branch: feat/AL-1234-user-authentication
# Prompt: Target branch: 1) develop 2) main
# Prompt: PR title? (press Enter for auto)
# Auto: "AL-1234: user authentication"

# Workflow completo
Complete-Feature -IssueKey "AL-1234"
# ✅ Verifica conflitos
# ✅ Cria PR para develop
# ✅ Para timer e loga no Jira
```

## Autocomplete e Validation

### ValidateSet

Parâmetros com valores limitados usam `ValidateSet`:

```powershell
New-Feature -Type <TAB>
# Mostra: feat, fix, hotfix, refactor, docs, test, chore

Open-Worktree -Editor <TAB>
# Mostra: zed, code, rider, vs

New-PR -Target <TAB>
# Mostra: develop, main
```

### Parameter Sets

Use `Get-Help` para ver parâmetros completos:

```powershell
Get-Help New-Feature -Parameter Type
# NAME: Type
# REQUIRED: false
# POSITION: named
# DEFAULT VALUE: feat
# ACCEPT PIPELINE INPUT: false
# ACCEPT WILDCARD CHARACTERS: false
# PARAMETER SET NAME: (All)
```

## Error Handling

Todas as funções incluem:
- ✅ Validação de comandos CLI (git, az, jira)
- ✅ Verificação de repositório git
- ✅ Validação de branch/worktree existente
- ✅ Mensagens de erro claras
- ✅ Sugestões de próximos passos

**Exemplos:**
```powershell
# Sem git repo
New-Worktree
# ❌ Not in a git repository

# Azure CLI não instalado
New-PR -Target develop
# ❌ Azure CLI not found. Install: winget install Microsoft.AzureCLI

# Jira CLI não instalado
Stop-Work -IssueKey AL-1234
# ⚠️  Jira CLI not found. Install from: https://github.com/ankitpokhrel/jira-cli
# 💡 Time not logged. Install Jira CLI and try: Stop-Work -IssueKey AL-1234
```

## Aliases

Todos os aliases antigos foram mantidos para compatibilidade:

**Worktrees:**
- `gwt` = `Get-Worktree`
- `gwtn` = `New-Worktree`
- `gwtr` = `Remove-Worktree`
- `gwto` = `Open-Worktree`
- `gwts` = `Get-WorktreeStatus`
- `gwtw` = `Switch-Worktree`
- `gwt-ai` = `New-WorktreeAI`

**Time Tracking:**
- `ws` = `Start-Work`
- `we` = `Stop-Work`
- `wt` = `Show-Work`

**PR Workflow:**
- `nf` = `New-Feature`
- `npr` = `New-PR`
- `cf` = `Complete-Feature`
- `prs` = `Get-MyPRs`

## Tips & Tricks

### 1. Combo: Feature + Timer + PR
```powershell
# Criar feature com timer automático
New-Feature -Name "oauth" -IssueKey "AL-1234"

# Trabalhar...

# Completar tudo de uma vez
Complete-Feature -IssueKey "AL-1234"
```

### 2. Worktree + AI Context
```powershell
New-WorktreeAI
# Cria worktree + arquivo .ai-context.md
# Perfeito para Copilot, Cursor, Windsurf
```

### 3. Pipeline com Validação
```powershell
# Verificar conflitos antes de criar PR
if (Test-DevConflict) {
    New-PR -Target develop
} else {
    New-MergeBranch
}
```

### 4. Usar -WhatIf para Dry Run
```powershell
Reset-Work -WhatIf
# What if: Performing the operation "Reset" on target "Current timer".
```

## Troubleshooting

### PSScriptAnalyzer Warnings

Todas as funções agora usam verbos aprovados. Warnings de `PSUseApprovedVerbs` foram eliminados.

### Tab Completion Não Funciona

Recarregue o profile:
```powershell
. $PROFILE
```

Ou force reload dos módulos:
```powershell
Get-Module | Remove-Module -Force
. $PROFILE
```

### Aliases Não Reconhecidos

Verifique se módulos foram carregados:
```powershell
Get-Module
# Deve listar: worktrees, time-tracker, pr-workflow
```

## Next Steps

Para usar TUI (Text User Interface) mais avançado no futuro, considere:
- **Spectre.Console** - TUI framework para .NET/PowerShell
- **Terminal.Gui** - Terminal UI toolkit
- **PSMenu** - Simple menu module

Instalação exemplo:
```powershell
Install-Module -Name Spectre.Console
```

---

**Documentação Relacionada:**
- [README.md](README.md) - Visão geral dos módulos
- [TIME_TRACKING.md](TIME_TRACKING.md) - Guia de time tracking
- [PR_WORKFLOW.md](PR_WORKFLOW.md) - Guia de PR workflow
- [WORKTREES.md](WORKTREES.md) - Guia de worktrees
