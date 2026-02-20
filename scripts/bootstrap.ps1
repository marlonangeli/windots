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

Write-Host "Bootstrap complete." -ForegroundColor Green
