[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"

. (Join-Path $scriptsRoot "common\logging.ps1")
. (Join-Path $repoRoot "modules\packages\manager.ps1")

function Invoke-WindotsModuleMise {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    if ($Context.SkipMise) {
        Log-Info "[mise] Skipped because -SkipMise was set."
        return
    }

    if (-not $Context.SkipInstall) {
        $mode = if ($Context.Mode) { $Context.Mode } else { "full" }
        Ensure-WindotsModulePackages -Module "mise" -Mode $mode -WhatIf:$Context.WhatIf
    }

    $setupPath = Join-Path $PSScriptRoot "setup.ps1"
    if (-not (Test-Path $setupPath)) {
        throw "[mise] Missing script: $setupPath"
    }

    if ($Context.WhatIf) {
        Log-Info "[mise] WhatIf: would configure mise and install toolchain."
        return
    }

    & $setupPath
    if ($LASTEXITCODE -ne 0) {
        throw "[mise] setup script failed with exit code $LASTEXITCODE"
    }

    if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
        Log-Warn "[mise] command not found after setup."
        return
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
        Log-Warn "[mise] mise doctor reported issues."
    }

    mise ls
}
