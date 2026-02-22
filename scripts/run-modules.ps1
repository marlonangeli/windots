[CmdletBinding()]
param(
    [ValidateSet("full", "clean")]
    [string]$Mode = "full",

    [string[]]$Modules,

    [switch]$SkipInstall,
    [switch]$SkipMise,
    [switch]$UseSymlinkAI,
    [switch]$SkipSecretsChecks,
    [switch]$IncludeSecretsChecks,
    [switch]$IncludeValidation,
    [switch]$NoPrompt,
    [switch]$WhatIf,
    [switch]$ListModules
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot "common\logging.ps1")
. (Join-Path $repoRoot "modules\module-registry.ps1")

if ($ListModules) {
    Get-WindotsModuleRegistry -ScriptsRoot $repoRoot |
        Select-Object -ExpandProperty Name
    return
}

$requestedModules = if ($Modules -and $Modules.Count -gt 0) {
    @($Modules)
}
else {
    Get-WindotsDefaultModules -Mode $Mode
}

if ($SkipMise) {
    $requestedModules = @($requestedModules | Where-Object { $_ -ne "mise" })
}

if ($IncludeSecretsChecks -and ($requestedModules -notcontains "secrets")) {
    $requestedModules += "secrets"
}

if ($SkipSecretsChecks) {
    $requestedModules = @($requestedModules | Where-Object { $_ -ne "secrets" })
}

if ($IncludeValidation -and ($requestedModules -notcontains "validate")) {
    $requestedModules += "validate"
}

$requestedModules = @(
    $requestedModules |
        ForEach-Object { $_.ToString().Trim().ToLowerInvariant() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
)

$plan = Resolve-WindotsModuleExecutionPlan -Mode $Mode -RequestedModules $requestedModules -ScriptsRoot $repoRoot
if (-not $plan -or $plan.Count -eq 0) {
    Log-Warn "No modules selected for execution."
    return
}

$loadedScripts = @{}
foreach ($module in $plan) {
    if ($loadedScripts.ContainsKey($module.ScriptPath)) {
        continue
    }

    if (-not (Test-Path $module.ScriptPath)) {
        throw "Module script not found for '$($module.Name)': $($module.ScriptPath)"
    }

    . $module.ScriptPath
    $loadedScripts[$module.ScriptPath] = $true
}

$context = @{
    Mode = $Mode
    SkipInstall = [bool]$SkipInstall
    SkipMise = [bool]$SkipMise
    UseSymlinkAI = [bool]$UseSymlinkAI
    SkipSecretsChecks = [bool]$SkipSecretsChecks
    NoPrompt = [bool]$NoPrompt
    WhatIf = [bool]$WhatIf
    ScriptsRoot = $PSScriptRoot
    RepoRoot = $repoRoot
}

$sequence = $plan | Select-Object -ExpandProperty Name
Log-Info ("Module execution order: " + ($sequence -join " -> "))

foreach ($module in $plan) {
    if (-not (Get-Command $module.EntryFunction -ErrorAction SilentlyContinue)) {
        throw "Module entrypoint not found: $($module.EntryFunction)"
    }

    Log-Step ("Running module: {0}" -f $module.Name)
    try {
        & $module.EntryFunction -Context $context
    }
    catch {
        throw "Module '$($module.Name)' failed: $($_.Exception.Message)"
    }
}
