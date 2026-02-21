# TODO: apenas verifica chezmoi, deve validar winget, pwsh, git e várias outras coisas
[CmdletBinding()]
param()

$scriptsRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $scriptsRoot "common\logging.ps1")

function Invoke-WindotsModuleCore {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    Log-Step "[core] Applying chezmoi changes"

    if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
        Log-Warn "[core] chezmoi not found. Install it first."
        return
    }

    if ($Context.WhatIf) {
        Log-Info "[core] WhatIf: would run 'chezmoi apply'."
        return
    }

    chezmoi apply
    if ($LASTEXITCODE -ne 0) {
        throw "[core] chezmoi apply failed with exit code $LASTEXITCODE"
    }
}
