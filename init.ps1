[CmdletBinding()]
param(
    [ValidateSet("full", "clean")]
    [string]$Mode = "full",

    [switch]$SkipBaseInstall,
    [switch]$UseSymlinkAI,
    [switch]$SkipSecretsChecks,
    [switch]$AutoApply,
    [switch]$NoPrompt,
    [string[]]$Modules,

    [string]$Repo = "marlonangeli/windots",
    [string]$Branch = "main",
    [string]$Ref,
    [string]$Host = "raw.githubusercontent.com",
    [switch]$RequireNonMain,
    [string]$LocalRepoPath
)

$ErrorActionPreference = "Stop"

Write-Warning "init.ps1 is deprecated. Use install.ps1 instead. Delegating to install.ps1..."

$installPath = Join-Path $PSScriptRoot "install.ps1"
if (-not (Test-Path $installPath)) {
    throw "install.ps1 not found at repository root."
}

& $installPath @PSBoundParameters
