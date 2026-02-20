# PowerShell Profile - Documentação

## 🚀 Quick Start

**New to this profile?** All major functions now support **interactive mode**!

```powershell
# Just run commands without parameters for guided prompts:
New-Worktree      # Create git worktree (interactive)
Start-Work        # Start time tracking (interactive)
New-Feature       # Create feature branch (interactive)
New-PR            # Create Pull Request (interactive)

# Startup modes
pmode             # show active mode (full|clean)
pclean            # set clean mode for next sessions
pfull             # set full mode for next sessions

# Get comprehensive help:
Get-Help New-Worktree -Full
Get-Help Start-Work -Examples

# Tab completion works everywhere:
New-Worktree -<TAB>  # Shows: BranchName, BaseBranch, Interactive
```

---

## ⚡ Install Script

Use the bootstrap script to install tooling with `winget` and optional fallbacks:

```powershell
# Full setup
.\Scripts\install-shell.ps1 -IncludeFont

# Fast/minimal setup
.\Scripts\install-shell.ps1 -Minimal

# Preview actions
.\Scripts\install-shell.ps1 -DryRun
```

---

## ⚡ Profile Modes

### `full` (default)
- Loads core modules + workflow modules (`worktrees`, `time-tracker`, `pr-workflow`)
- Enables lazy Oh-My-Posh prompt initialization
- Best for daily dev flow

### `clean`
- Loads only core config + aliases + utilities
- Skips heavy workflow modules on startup
- Best for very fast shell startup and troubleshooting

## 📁 Estrutura do Perfil

```
PowerShell/
├── Microsoft.PowerShell_profile.ps1    # Perfil principal (carrega módulos)
├── modules/                             # Módulos organizados por funcionalidade
│   ├── config.ps1                       # Configurações e variáveis de ambiente
│   ├── aliases.ps1                      # Aliases para Git, Docker, Dotnet, etc
│   ├── utils.ps1                        # Funções utilitárias
│   ├── worktrees.psm1                   # Gerenciamento de git worktrees ⭐ NEW
│   ├── time-tracker.psm1                # Controle de tempo + Jira ⭐ NEW
│   └── pr-workflow.psm1                 # Workflow de Pull Requests ⭐ NEW
├── Modules/                             # Módulos PowerShell externos
│   ├── GitAliases/
│   ├── Terminal-Icons/
│   └── BWSecret/
├── docs/                                # Documentação
│   ├── README.md                        # Este arquivo
│   ├── INTERACTIVE_USAGE.md             # Guia de uso interativo ⭐ NEW
│   ├── CHANGELOG.md                     # Registro de mudanças ⭐ NEW
│   ├── TIME_TRACKING.md                 # Guia de time tracking
│   ├── PR_WORKFLOW.md                   # Guia de PR workflow
│   └── WORKTREES.md                     # Guia de worktrees
└── old/                                 # Backups de versões anteriores
```

---

## ⭐ Novidades (Latest Update)

### ✅ Modo Interativo
Todas as funções principais agora solicitam parâmetros interativamente quando não fornecidos:
- `New-Worktree` - Prompts para nome e base branch
- `Start-Work` - Prompts para issue key e descrição
- `New-Feature` - Wizard completo para criação de features
- `New-PR` - Criação guiada de Pull Request

### ✅ Comment-Based Help
Documentação completa integrada ao PowerShell:
- `Get-Help <comando>` - Ajuda completa
- `Get-Help <comando> -Examples` - Exemplos de uso
- `Get-Help <comando> -Parameter <param>` - Ajuda de parâmetro específico
- Tab completion funciona em todos os parâmetros

### ✅ Verbos Aprovados
Todas as funções agora usam verbos aprovados do PowerShell (sem warnings):
- `Get-Worktree` (era `gwt-list`)
- `New-Worktree` (era `gwt-new`)
- `Start-Work`, `Stop-Work` (verbos corretos)
- Aliases mantidos para compatibilidade

### ✅ Validação e Error Handling
- Validação de formato de issue keys
- Verificação de CLIs instalados (git, az, jira)
- Mensagens de erro claras
- Sugestões de próximos passos

---

## 🚀 Início Rápido

### Recarregar Perfil
```powershell
reload    # ou . $PROFILE
```

### Editar Perfil
```powershell
ep        # Abre no Zed
```

---

## 📦 Módulos

### 1. config.ps1
**Responsabilidade:** Configurações iniciais, variáveis de ambiente, PSReadLine, Oh-My-Posh, Zoxide

**Variáveis exportadas:**
- `$env:EDITOR` → `zed`
- `$env:DOTNET_CLI_TELEMETRY_OPTOUT` → `1`
- `$env:POWERSHELL_TELEMETRY_OPTOUT` → `1`

**Funções:**
- `z`, `zi` - Zoxide (lazy load)

---

### 2. aliases.ps1
**Responsabilidade:** Aliases para comandos comuns

#### Git
```powershell
g, gs, ga, gc, gp, gpl, gco, gcb, gd, gl, gll
gst, gstp, gaa, gcam, gf, gb, gr
```

#### Docker
```powershell
d, dc, dps, dpsa, dimg, dstop, drm, drmi
dprune, dlogs, dexec, dsh, dbash
```

#### Dotnet
```powershell
dn, dnr, dnb, dnt, dnc, dnw, dnrs, dnp
```

#### Node/NPM
```powershell
ni, nid, nr, ns, nt, nb, nci
```

#### Navegação
```powershell
.., ..., ...., ~, docs, dl, ubuntu (u)
```

---

### 3. utils.ps1
**Responsabilidade:** Funções utilitárias gerais

#### Arquivos
```powershell
la           # List all (força exibição de ocultos)
ll           # List com Terminal-Icons
which        # Localiza comando
touch        # Cria arquivo vazio
mkcd / take  # Cria diretório e navega
```

#### Editores
```powershell
edit         # Zed (padrão)
z-edit       # Zed
c-edit, c    # VS Code
vs           # Visual Studio
rider        # JetBrains Rider
```

#### Utilitários
```powershell
reload       # Recarrega perfil
ep           # Edita perfil no Zed
sop          # Sophos password
```

---

### 4. worktrees.ps1
**Responsabilidade:** Gerenciamento de git worktrees

Veja documentação completa em: [WORKTREES.md](./WORKTREES.md)

```powershell
gwt-new feature-name          # Cria worktree
gwt-ai "feature" -Description  # Cria com contexto IA
gwt-switch                     # Navega entre worktrees
gwt-open feature-name          # Abre no editor
gwt-status                     # Status de todos
gwt-remove feature-name        # Remove worktree
```

---

### 5. time-tracker.ps1
**Responsabilidade:** Controle de tempo integrado com Jira

Veja documentação completa em: [TIME_TRACKING.md](./TIME_TRACKING.md)

```powershell
Start-Work AL-123 -Description "..."    # Inicia timer
Show-Work                                 # Mostra tempo atual
Stop-Work -IssueKey AL-123 -Comment "..."  # Para e loga no Jira
```

**Aliases:** `ws`, `wt`, `we`, `work-start`, `work-stop`, `work-show`

---

### 6. pr-workflow.ps1
**Responsabilidade:** Workflow de Pull Requests (Azure DevOps)

Veja documentação completa em: [PR_WORKFLOW.md](./PR_WORKFLOW.md)

**Workflow:** `main → feat/fix → PR develop → PR main`

```powershell
New-Feature "auth" -Type feat -IssueKey AL-123    # Cria feature branch
Test-DevConflict                                  # Verifica conflitos
New-PR -Target develop -IssueKey AL-123           # Cria PR para develop
Complete-Feature -IssueKey AL-123                 # Workflow completo
Get-MyPRs                                         # Lista seus PRs
```

**Aliases:** `nf`, `npr`, `cf`, `prs`

---

## 🔧 Customização

### Adicionar Novo Módulo

1. Crie arquivo em `modules/meu-modulo.ps1`
2. Adicione funções/aliases
3. Carregue no perfil principal:

```powershell
# Microsoft.PowerShell_profile.ps1
. "$ProfileDir\modules\meu-modulo.ps1"
```

### Desabilitar Módulo

Comente a linha de import no perfil principal:

```powershell
# . "$ProfileDir\modules\time-tracker.ps1"   # Desabilitado
```

---

## 🎨 Temas e Configurações

### Oh-My-Posh
- Tema: Catppuccin Mocha
- Config: `$env:POSH_THEMES_PATH\catppuccin_mocha.omp.json`

### PSReadLine
- PredictionSource: History
- PredictionViewStyle: ListView
- EditMode: Windows

### Terminal
- Font: JetBrainsMono Nerd Font Mono
- Theme: Catppuccin Mocha
- Editor padrão: Zed

---

## 📚 Links Úteis

- [Jira CLI](https://github.com/ankitpokhrel/jira-cli)
- [Azure CLI](https://docs.microsoft.com/cli/azure/)
- [Oh-My-Posh](https://ohmyposh.dev/)
- [Zoxide](https://github.com/ajeetdsouza/zoxide)
- [Terminal-Icons](https://github.com/devblackops/Terminal-Icons)

---

## 🐛 Troubleshooting

### Módulo não carrega
```powershell
# Verifique erros
$Error[0]

# Teste carregamento manual
. "C:\...\modules\nome-modulo.ps1"
```

### Performance lenta
```powershell
# Medir tempo de carregamento
Measure-Command { . $PROFILE }

# Desabilitar módulos não essenciais
```

### Jira CLI não funciona
```powershell
# Verificar instalação
jira --version

# Configurar
jira init
```

---

## 📝 Changelog

### v2.0.0 - Modular
- ✅ Separação em módulos
- ✅ Time tracking com Jira
- ✅ PR workflow Azure DevOps
- ✅ Documentação completa

### v1.0.0 - Monolítico
- ✅ Perfil único
- ✅ Aliases básicos
- ✅ Oh-My-Posh + Zoxide
