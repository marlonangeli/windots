# Time Tracking com Jira

## 📊 Visão Geral

Sistema de controle de tempo integrado com Jira CLI para registrar worklogs automaticamente.

---

## 🚀 Comandos

### Iniciar Timer
```powershell
Start-Work                              # Timer simples
Start-Work AL-123                       # Timer com issue key
Start-Work AL-123 -Description "Fix login bug"  # Com descrição
```

**Aliases:** `ws`, `work-start`

### Mostrar Tempo Atual
```powershell
Show-Work    # Mostra tempo decorrido sem parar
```

**Aliases:** `wt`, `work-show`

### Parar Timer e Logar
```powershell
Stop-Work                                # Para timer (sem log)
Stop-Work -IssueKey AL-123               # Para e loga no Jira
Stop-Work -IssueKey AL-123 -Comment "Completed feature"  # Com comentário
Stop-Work -NoLog                         # Para sem logar (mesmo com issue key)
```

**Aliases:** `we`, `work-stop`

---

## 💼 Workflows

### Workflow 1: Feature Development
```powershell
# 1. Criar feature e iniciar timer
New-Feature "user-auth" -Type feat -IssueKey AL-123
# Timer inicia automaticamente

# 2. Trabalhar...
# git add, commit, etc

# 3. Verificar tempo
Show-Work
# ⏱️  Current Time: 02:30:15
# 📋 Issue: AL-123

# 4. Completar feature (para timer e loga)
Complete-Feature -IssueKey AL-123
```

### Workflow 2: Multiple Tasks
```powershell
# Task 1
Start-Work AL-100 -Description "Bug fix"
# ... trabalho ...
Stop-Work -IssueKey AL-100

# Task 2
Start-Work AL-101 -Description "Code review"
# ... trabalho ...
Stop-Work -IssueKey AL-101
```

### Workflow 3: Manual Tracking
```powershell
# Iniciar sem issue key
Start-Work -Description "Research"

# Trabalhar...

# Parar e especificar issue depois
Stop-Work -IssueKey AL-105 -Comment "Completed research phase"
```

---

## 📝 Formato Jira

O tempo é automaticamente convertido para o formato Jira:

| Tempo Real  | Formato Jira |
|-------------|--------------|
| 1:30:00     | 1h 30m       |
| 2:05:00     | 2h 5m        |
| 0:45:00     | 45m          |
| 3:00:00     | 3h           |

---

## 🔧 Integração com Jira CLI

### Pré-requisitos
```powershell
# Instalar Jira CLI
winget install ankitpokhrel.jira-cli

# Configurar
jira init
```

### Comandos Jira Gerados

Quando você usa `Stop-Work -IssueKey AL-123`, o sistema executa:

```bash
jira issue worklog add AL-123 "2h 30m" --comment "Working on feat/AL-123-user-auth" --no-input
```

---

## 📊 Estado do Timer

O timer mantém estado global em `$global:__TimeTracker`:

```powershell
$global:__TimeTracker
# Start       : DateTime do início
# IssueKey    : Issue key (ex: AL-123)
# Description : Descrição da tarefa
```

---

## 💡 Dicas

### ✅ Boas Práticas
- Use `Start-Work` com `IssueKey` desde o início
- Use descrições significativas para contexto
- `Show-Work` periodicamente para acompanhar tempo
- Sempre pare o timer antes de sair

### ⚠️ Cuidados
- Timer não persiste entre sessões (fecha terminal = perde timer)
- Um timer ativo por vez
- Sem suporte para múltiplos timers simultâneos (por enquanto)

---

## 🎯 Exemplos Práticos

### Exemplo 1: Dia de Desenvolvimento
```powershell
# Manhã: Feature nova
ws AL-123 -Description "Implement OAuth"
# ... 3 horas depois ...
we -IssueKey AL-123 -Comment "OAuth integration completed"

# Tarde: Bug fix
ws AL-124 -Description "Fix memory leak"
# ... 2 horas depois ...
we -IssueKey AL-124 -Comment "Memory leak resolved"
```

### Exemplo 2: Code Review
```powershell
# Revisar PR
ws AL-125 -Description "Code review PR #45"
# ... análise ...
we -IssueKey AL-125 -Comment "Code review completed, approved with suggestions"
```

### Exemplo 3: Research/Spike
```powershell
# Pesquisa sem issue definida
ws -Description "Research new architecture pattern"
# ... pesquisa ...
# Decidiu associar a uma issue depois
we -IssueKey AL-126 -Comment "Architecture research completed - recommend microservices"
```

---

## 🔮 Melhorias Futuras

Planejado para próximas versões:

- [ ] Persistência entre sessões
- [ ] Múltiplos timers simultâneos
- [ ] Exportar relatório de tempo
- [ ] Integração com outras ferramentas (Toggl, Clockify)
- [ ] Dashboard visual de tempo
- [ ] Estatísticas semanais/mensais
- [ ] Auto-pause em inatividade
- [ ] Notificações de tempo (Pomodoro)

---

## 🐛 Troubleshooting

### Timer não inicia
```powershell
# Verificar se há timer ativo
Show-Work

# Forçar reset
$global:__TimeTracker = @{ Start = $null; IssueKey = $null; Description = $null }
```

### Jira worklog falha
```powershell
# Verificar conexão Jira
jira me

# Testar manualmente
jira issue worklog add AL-123 "1h" --no-input

# Ver logs detalhados
jira issue worklog add AL-123 "1h" --debug
```

### Tempo perdido ao fechar terminal
**Solução atual:** Sempre pare o timer antes de fechar

**Solução futura:** Implementar persistência em arquivo
