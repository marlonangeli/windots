# Setup

## 1) Instalar ferramentas base

```powershell
winget install twpayne.chezmoi Git.Git Microsoft.PowerShell GitHub.cli
```

## 2) Aplicar dotfiles

```powershell
chezmoi init --apply <SEU_USER_GITHUB>/windots
```

## 3) Bootstrap (recomendado)

```powershell
pwsh ./scripts/bootstrap.ps1 -Mode full
```

Notas:
- `-Mode clean` reduz instalação para cenário mais enxuto.
- `-SkipInstall` aplica configs sem reinstalar ferramentas.

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
