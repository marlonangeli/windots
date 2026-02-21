[CmdletBinding()]
param(
    [string]$Repo = "marlonangeli/windots",
    [string]$Branch = "main",
    [string]$Ref,
    [switch]$RequireNonMain,
    [string]$LocalRepoPath,

    [ValidateSet("full", "clean")]
    [string]$Mode = "full",

    [switch]$SkipBaseInstall,
    [switch]$UseSymlinkAI,
    [switch]$SkipSecretsChecks,
    [string]$LogPath,
    [switch]$AutoApply,
    [switch]$NoPrompt,
    [string[]]$Modules
)

$ErrorActionPreference = "Stop"

Write-Warning "scripts/install-from-repo.ps1 is deprecated. Use scripts/install.ps1 instead. Delegating..."

$canonical = Join-Path $PSScriptRoot "install.ps1"
if (-not (Test-Path $canonical)) {
    throw "Canonical installer not found: $canonical"
}

& $canonical @PSBoundParameters
