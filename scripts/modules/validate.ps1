[CmdletBinding()]
param()

$scriptsRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $scriptsRoot "common\logging.ps1")

function Invoke-WindotsModuleValidate {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    $scriptPath = Join-Path $scriptsRoot "validate.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "[validate] Missing script: $scriptPath"
    }

    if ($Context.WhatIf) {
        Log-Info "[validate] WhatIf: would run repository validation."
        return
    }

    Log-Step "[validate] Running repository validation"
    & $scriptPath
    if ($LASTEXITCODE -ne 0) {
        throw "[validate] validate.ps1 failed with exit code $LASTEXITCODE"
    }
}
