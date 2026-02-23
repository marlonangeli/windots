[CmdletBinding()]
param(
    [ValidateSet("full", "clean")]
    [string]$Mode = "full",

    [switch]$SkipInstall,
    [switch]$SkipMise,
    [switch]$UseSymlinkAI,
    [switch]$SkipSecretsChecks,
    [switch]$IncludeSecretsChecks,
    [switch]$NoPrompt,
    [string[]]$Modules,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common\logging.ps1")

$runnerPath = Join-Path $PSScriptRoot "run-modules.ps1"
if (-not (Test-Path $runnerPath)) {
    throw "Missing module runner: $runnerPath"
}

$runnerArgs = @{
    Mode = $Mode
    SkipInstall = [bool]$SkipInstall
    SkipMise = [bool]$SkipMise
    UseSymlinkAI = [bool]$UseSymlinkAI
    SkipSecretsChecks = [bool]$SkipSecretsChecks
    IncludeSecretsChecks = [bool]$IncludeSecretsChecks
    NoPrompt = [bool]$NoPrompt
    WhatIf = [bool]$WhatIf
}

if ($Modules -and $Modules.Count -gt 0) {
    $runnerArgs.Modules = $Modules
}

& $runnerPath @runnerArgs
if (-not $?) {
    throw "Module runner failed"
}

Log-Info "Bootstrap complete."
