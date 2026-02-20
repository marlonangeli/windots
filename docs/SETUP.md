# Setup

## 1) Instalar ferramentas base

```powershell
winget install twpayne.chezmoi Git.Git Microsoft.PowerShell GitHub.cli
```

## 2) Aplicar dotfiles

```powershell
chezmoi init --apply <SEU_USER_GITHUB>/windots
```

## 3) Bootstrap

```powershell
pwsh ./scripts/bootstrap.ps1 -Mode full
```

## 4) Validar

```powershell
pwsh ./scripts/validate.ps1
```
