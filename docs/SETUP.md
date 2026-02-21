# Setup

## 1) Instalar ferramentas base

```powershell
winget install twpayne.chezmoi Git.Git Microsoft.PowerShell GitHub.cli
```

Pacotes opcionais recomendados:

```powershell
winget install jdx.mise JanDeDobbeleer.OhMyPosh charmbracelet.gum
```

## 2) Aplicar dotfiles

```powershell
chezmoi init --apply <SEU_USER_GITHUB>/windots
```

Alternativa em comando único (remote install script):

```powershell
irm https://windots.ilegna.dev/install | iex
```

Por padrão esse comando só inicializa/clona o source do `chezmoi` e exibe os próximos passos para execução manual.
Se quiser fluxo automático completo:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/marlonangeli/windots/main/install.ps1"))) -AutoApply
```

O fluxo pergunta dados de configuração (Git/GitHub/Azure opcional).  
Para modo silencioso: `-NoPrompt`.
Para seleção explícita de módulos no fluxo automático: `-Modules core,shell,terminal`.
Para testar por branch/ref/local: `-Branch`, `-Ref`, `-LocalRepoPath`.

Exemplos de teste:

```powershell
pwsh -NoProfile -File ./install.ps1 -Branch feature/install-refactor -AutoApply
pwsh -NoProfile -File ./install.ps1 -Ref <sha-ou-tag> -AutoApply
pwsh -NoProfile -File ./install.ps1 -LocalRepoPath C:\\src\\windots -AutoApply
```

Retry sem reinstalar dependências base:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/marlonangeli/windots/main/install.ps1"))) -SkipBaseInstall
```

Se necessário, reabra o terminal antes do retry para garantir PATH atualizado.
Se aparecer erro de script de bootstrap não encontrado, valide o root esperado do chezmoi:
`$HOME/.local/share/chezmoi`.

## 3) Bootstrap (recomendado)

```powershell
pwsh ./scripts/bootstrap.ps1 -Mode full
```

Notas:
- `-Mode clean` reduz instalação para cenário mais enxuto.
- `-SkipInstall` aplica configs sem reinstalar ferramentas.
- `-SkipMise` aplica bootstrap sem `mise install/doctor/ls`.
- `-Modules core,shell,terminal` executa apenas módulos selecionados (dependências são resolvidas automaticamente).
- O bootstrap instala um `profile shim` no caminho oficial do PowerShell (mesmo em OneDrive Documents), redirecionando para `~/.config/powershell`.
- Se já existir profile, o script pede confirmação e salva backup antes de substituir.
- Para restaurar profile anterior: `pwsh ./scripts/install-profile-shim.ps1 -Action reset`.

## 4) Fluxo seguro de update/apply

Wrapper recomendado para operação diária:

```powershell
pwsh ./scripts/windots.ps1 -Command update
```

Outros comandos disponíveis:

```powershell
pwsh ./scripts/windots.ps1 -Command apply
pwsh ./scripts/windots.ps1 -Command bootstrap -Mode clean
pwsh ./scripts/windots.ps1 -Command validate
```

## 5) Validar consistência e segredos

```powershell
pwsh ./scripts/validate.ps1
pwsh ./scripts/validate-modules.ps1
```

## 6) Confirmar toolchain mise

```powershell
mise install
mise doctor
mise ls
```

## 7) Sincronizar AI configs manualmente (opcional)

```powershell
pwsh ./scripts/link-ai-configs.ps1
# ou
pwsh ./scripts/link-ai-configs.ps1 -UseSymlink
```

## Pós-update do Windows Terminal

Após `chezmoi apply`/`chezmoi update`, um hook pós-execução replica automaticamente:

- origem: `~/.config/windows-terminal/settings.json`
- destino: `~/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json`
- implementação: `home/.chezmoiscripts/run_after_40-sync-windows-terminal.ps1.tmpl`

## Oh My Posh (tema + fonte)

O bootstrap chama `scripts/setup-oh-my-posh.ps1` para preparar:

- tema `catppuccin_mocha.omp.json` em `POSH_THEMES_PATH`
- fonte Nerd Font JetBrains Mono (com fallback de instalação)

## Referências

- [README](../README.md)
- [Segredos](./SECRETS.md)
- [Perfil PowerShell](../home/dot_config/powershell/docs/README.md)
