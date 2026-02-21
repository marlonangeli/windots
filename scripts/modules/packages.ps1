[CmdletBinding()]
param()

$scriptsRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $scriptsRoot "common\logging.ps1")

function Invoke-WindotsModulePackages {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    if ($Context.SkipInstall) {
        Log-Info "[packages] Skipped because -SkipInstall was set."
        return
    }

    $mode = if ($Context.Mode) { $Context.Mode } else { "full" }
    # TODO: deveria ser o próprio módulo que decide quais modos suporta, e não o script de instalação genérico. Talvez o módulo deva expor uma função Get-SupportedModes ou algo assim, e o script de instalação deveria validar se o modo passado é suportado.
    $scriptPath = Join-Path $scriptsRoot "install-tools.ps1"

    if (-not (Test-Path $scriptPath)) {
        throw "[packages] Missing script: $scriptPath"
    }

    if ($Context.WhatIf) {
        Log-Info "[packages] WhatIf: would run install-tools in mode '$mode'."
        return
    }

    Log-Step "[packages] Installing tools for mode '$mode'"
    & $scriptPath -Mode $mode
    if ($LASTEXITCODE -ne 0) {
        throw "[packages] install-tools failed with exit code $LASTEXITCODE"
    }
}
