# Setup

## 1) Instalar ferramentas base

```powershell
winget install twpayne.chezmoi Git.Git Microsoft.PowerShell GitHub.cli
```

## 2) Aplicar dotfiles

```powershell
chezmoi init --apply <SEU_USER_GITHUB>/windots
```

Alternativa em comando único (remote install script):

```powershell
irm https://raw.githubusercontent.com/marlonangeli/windots/main/init.ps1 | iex
```

Retry sem reinstalar dependências base:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/marlonangeli/windots/main/init.ps1"))) -SkipBaseInstall
```

## 3) Bootstrap (recomendado)

```powershell
pwsh ./scripts/bootstrap.ps1 -Mode full
```

Notas:
- `-Mode clean` reduz instalação para cenário mais enxuto.
- `-SkipInstall` aplica configs sem reinstalar ferramentas.
- O bootstrap instala um `profile shim` no caminho oficial do PowerShell (mesmo em OneDrive Documents), redirecionando para `~/.config/powershell`.
- Se já existir profile, o script pede confirmação e salva backup antes de substituir.
- Para restaurar profile anterior: `pwsh ./scripts/install-profile-shim.ps1 -Action reset`.

## 4) Validar consistência e segredos

```powershell
pwsh ./scripts/validate.ps1
```

## 5) Sincronizar AI configs manualmente (opcional)

```powershell
pwsh ./scripts/link-ai-configs.ps1
# ou
pwsh ./scripts/link-ai-configs.ps1 -UseSymlink
```

## Referências

- [README](../README.md)
- [Segredos](./SECRETS.md)
- [Perfil PowerShell](../home/dot_config/powershell/docs/README.md)
