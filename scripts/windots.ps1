# TODO: adicionar documentação, evitar flags de Skip desnecessarios
[CmdletBinding()]
param(
    [ValidateSet("bootstrap", "apply", "update", "validate")]
    [string]$Command = "update",

    [ValidateSet("full", "clean")]
    [string]$Mode = "full",

    [string[]]$Modules,

    [switch]$SkipInstall,
    [switch]$SkipMise,
    [switch]$UseSymlinkAI,
    [switch]$SkipSecretsChecks,
    [switch]$NoPrompt,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common\logging.ps1")

$bootstrapPath = Join-Path $PSScriptRoot "bootstrap.ps1"
$validatePath = Join-Path $PSScriptRoot "validate.ps1"

if (-not (Test-Path $bootstrapPath)) { throw "Missing bootstrap script: $bootstrapPath" }
if (-not (Test-Path $validatePath)) { throw "Missing validate script: $validatePath" }

function Invoke-ChezmoiCommand {
    param([Parameter(Mandatory)][string[]]$Args)

    if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
        throw "chezmoi not found in PATH"
    }

    # TODO: o que WhatIf deve fazer?
    if ($WhatIf) {
        Log-Info ("WhatIf: would run 'chezmoi {0}'" -f ($Args -join " "))
        return
    }

    & chezmoi @Args
    if ($LASTEXITCODE -ne 0) {
        throw "chezmoi $($Args -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Invoke-Bootstrap {
    param(
        [bool]$SkipInstallFlag
    )

    $bootstrapArgs = @{
        Mode = $Mode
        SkipInstall = $SkipInstallFlag
        SkipMise = [bool]$SkipMise
        UseSymlinkAI = [bool]$UseSymlinkAI
        NoPrompt = [bool]$NoPrompt
        IncludeSecretsChecks = (-not [bool]$SkipSecretsChecks)
        WhatIf = [bool]$WhatIf
    }

    if ($Modules -and $Modules.Count -gt 0) {
        $bootstrapArgs.Modules = $Modules
    }

    & $bootstrapPath @bootstrapArgs
}

switch ($Command) {
    "bootstrap" {
        Invoke-Bootstrap -SkipInstallFlag ([bool]$SkipInstall)
    }

    "apply" {
        Log-Step "Running chezmoi apply..."
        Invoke-ChezmoiCommand -Args @("apply")

        Log-Step "Running validation..."
        if (-not $WhatIf) {
            & $validatePath
            if ($LASTEXITCODE -ne 0) { throw "validate.ps1 failed with exit code $LASTEXITCODE" }
        }
        else {
            Log-Info "WhatIf: would run validate.ps1"
        }
    }

    "update" {
        Log-Step "Running chezmoi update..."
        Invoke-ChezmoiCommand -Args @("update")

        $skipInstallForUpdate = $true
        if ($PSBoundParameters.ContainsKey("SkipInstall")) {
            $skipInstallForUpdate = [bool]$SkipInstall
        }

        Log-Step "Running bootstrap workflow..."
        Invoke-Bootstrap -SkipInstallFlag $skipInstallForUpdate

        Log-Step "Running validation..."
        if (-not $WhatIf) {
            & $validatePath
            if ($LASTEXITCODE -ne 0) { throw "validate.ps1 failed with exit code $LASTEXITCODE" }
        }
        else {
            Log-Info "WhatIf: would run validate.ps1"
        }
    }

    "validate" {
        Log-Step "Running validation..."
        if (-not $WhatIf) {
            & $validatePath
            if ($LASTEXITCODE -ne 0) { throw "validate.ps1 failed with exit code $LASTEXITCODE" }
        }
        else {
            Log-Info "WhatIf: would run validate.ps1"
        }
    }
}
