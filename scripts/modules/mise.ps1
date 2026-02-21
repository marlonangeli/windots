[CmdletBinding()]
param()

$scriptsRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $scriptsRoot "common\logging.ps1")

function Invoke-WindotsModuleMise {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    if ($Context.SkipMise) {
        Log-Info "[mise] Skipped because -SkipMise was set."
        return
    }

    if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
        Log-Warn "[mise] mise not found. Install it first or use -SkipMise."
        return
    }

    # TODO: setup mise deveria estar em um modulo especifico
    $setupPath = Join-Path $scriptsRoot "setup-mise.ps1"
    if (-not (Test-Path $setupPath)) {
        throw "[mise] Missing script: $setupPath"
    }

    if ($Context.WhatIf) {
        Log-Info "[mise] WhatIf: would configure mise PATH and install toolchain."
        return
    }

    Log-Step "[mise] Configuring PATH and shell activation"
    & $setupPath
    if ($LASTEXITCODE -ne 0) {
        throw "[mise] setup-mise failed with exit code $LASTEXITCODE"
    }

    $miseConfig = Join-Path $HOME ".config\mise\config.toml"
    if (-not (Test-Path $miseConfig)) {
        Log-Warn "[mise] config not found: $miseConfig"
        return
    }

    Log-Step "[mise] Installing toolchain"
    mise install
    if ($LASTEXITCODE -ne 0) {
        throw "[mise] mise install failed"
    }

    mise doctor
    if ($LASTEXITCODE -ne 0) {
        Log-Warn "[mise] mise doctor reported issues. Review output above."
    }

    mise ls
}
