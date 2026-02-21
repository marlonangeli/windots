[CmdletBinding()]
param()

$scriptsRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $scriptsRoot "common\logging.ps1")

function Invoke-WindotsModuleThemes {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    # TODO: mover script de configuração de temas para o modulo de shell, junto com outros scripts relacionados como oh-my-posh
    $scriptPath = Join-Path $scriptsRoot "setup-oh-my-posh.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "[themes] Missing script: $scriptPath"
    }

    if ($Context.WhatIf) {
        Log-Info "[themes] WhatIf: would configure oh-my-posh theme and font."
        return
    }

    Log-Step "[themes] Configuring oh-my-posh"
    & $scriptPath
    if ($LASTEXITCODE -ne 0) {
        throw "[themes] setup-oh-my-posh failed with exit code $LASTEXITCODE"
    }
}
