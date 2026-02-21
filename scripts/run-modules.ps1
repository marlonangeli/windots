# TODO: novamente varios parametros sem documentacao e com complexidade que pode ser simplificada
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

. (Join-Path $PSScriptRoot "common\logging.ps1")
. (Join-Path $PSScriptRoot "modules\module-registry.ps1")

if ($ListModules) {
    Get-WindotsModuleRegistry -ScriptsRoot $PSScriptRoot |
        Select-Object -ExpandProperty Name
    return
}

$requestedModules = if ($Modules -and $Modules.Count -gt 0) {
    @($Modules)
}
else {
    Get-WindotsDefaultModules -Mode $Mode
}

if ($IncludeSecretsChecks -and ($requestedModules -notcontains "secrets")) {
    $requestedModules += "secrets"
}

if ($IncludeValidation -and ($requestedModules -notcontains "validate")) {
    $requestedModules += "validate"
}

$plan = Resolve-WindotsModuleExecutionPlan -Mode $Mode -RequestedModules $requestedModules -ScriptsRoot $PSScriptRoot
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
    RepoRoot = (Split-Path -Parent $PSScriptRoot)
}

$sequence = $plan | Select-Object -ExpandProperty Name
Log-Info ("Module execution order: " + ($sequence -join " -> "))

# TODO: uso desnecessario de varias flags de skip, que podem ser simplificadas utilizando uma estrutura de configuração mais clara e menos propensa a erros. Além disso, a lógica de execução dos módulos poderia ser melhorada para lidar com dependências e pré-requisitos de forma mais robusta, evitando a necessidade de verificações manuais e garantindo uma execução mais fluida e confiável dos módulos.
foreach ($module in $plan) {
    if ($module.Name -eq "packages" -and $SkipInstall) {
        Log-Info "Skipping module 'packages' because -SkipInstall was set."
        continue
    }

    if ($module.Name -eq "mise" -and $SkipMise) {
        Log-Info "Skipping module 'mise' because -SkipMise was set."
        continue
    }

    if ($module.Name -eq "secrets" -and $SkipSecretsChecks) {
        Log-Info "Skipping module 'secrets' because -SkipSecretsChecks was set."
        continue
    }

    if (-not (Get-Command $module.EntryFunction -ErrorAction SilentlyContinue)) {
        throw "Module entrypoint not found: $($module.EntryFunction)"
    }

    Log-Step ("Running module: {0}" -f $module.Name)

    # TODO: sem error handling
    & $module.EntryFunction -Context $context
}
