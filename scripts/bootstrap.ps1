[CmdletBinding()]
param(
    [ValidateSet("full","clean")]
    [string]$Mode = "full",
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"

if (-not $SkipInstall) {
    & "$PSScriptRoot\install-tools.ps1" -Mode $Mode
}

Write-Host "Applying chezmoi changes..." -ForegroundColor Cyan
if (Get-Command chezmoi -ErrorAction SilentlyContinue) {
    chezmoi apply
} else {
    Write-Warning "chezmoi not found. Install it first."
}

Write-Host "Linking AI config..." -ForegroundColor Cyan
& "$PSScriptRoot\link-ai-configs.ps1"

Write-Host "Installing PowerShell profile shim..." -ForegroundColor Cyan
& "$PSScriptRoot\install-profile-shim.ps1"

Write-Host "Configuring oh-my-posh themes and fonts..." -ForegroundColor Cyan
& "$PSScriptRoot\setup-oh-my-posh.ps1"

if (Get-Command mise -ErrorAction SilentlyContinue) {
    $miseConfig = Join-Path $HOME ".config\mise\config.toml"
    if (Test-Path $miseConfig) {
        Write-Host "Installing mise toolchain..." -ForegroundColor Cyan
        mise install
        if ($LASTEXITCODE -ne 0) { throw "mise install failed" }
        mise doctor
        if ($LASTEXITCODE -ne 0) { Write-Warning "mise doctor reported issues. Review output above." }
        mise ls
    } else {
        Write-Warning "mise config not found: $miseConfig"
    }
}

Write-Host "Bootstrap complete." -ForegroundColor Green
