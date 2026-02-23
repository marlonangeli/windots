[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"

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
    if (-not $?) {
        throw "[validate] validate.ps1 failed."
    }
}
