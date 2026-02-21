[CmdletBinding()]
param()

$scriptsRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $scriptsRoot "common\logging.ps1")

function Invoke-WindotsModuleShell {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    # TODO: mover script de instalação do profile shim para o módulo shell
    $scriptPath = Join-Path $scriptsRoot "install-profile-shim.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "[shell] Missing script: $scriptPath"
    }

    if ($Context.WhatIf) {
        Log-Info "[shell] WhatIf: would install PowerShell profile shim."
        return
    }

    Log-Step "[shell] Installing PowerShell profile shim"
    if ($Context.NoPrompt) {
        & $scriptPath -Action install -Force
    }
    else {
        & $scriptPath -Action install
    }

    if ($LASTEXITCODE -ne 0) {
        throw "[shell] install-profile-shim failed with exit code $LASTEXITCODE"
    }
}
