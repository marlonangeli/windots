[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"

. (Join-Path $scriptsRoot "common\logging.ps1")
. (Join-Path $repoRoot "modules\packages\manager.ps1")

function Invoke-WindotsModuleThemes {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    if (-not $Context.SkipInstall) {
        $mode = if ($Context.Mode) { $Context.Mode } else { "full" }
        Ensure-WindotsModulePackages -Module "themes" -Mode $mode -WhatIf:$Context.WhatIf
    }

    $scriptPath = Join-Path $PSScriptRoot "setup.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "[themes] Missing script: $scriptPath"
    }

    if ($Context.WhatIf) {
        Log-Info "[themes] WhatIf: would configure oh-my-posh theme."
        return
    }

    Log-Step "[themes] Configuring oh-my-posh"
    & $scriptPath
    if ($LASTEXITCODE -ne 0) {
        throw "[themes] setup failed with exit code $LASTEXITCODE"
    }
}
