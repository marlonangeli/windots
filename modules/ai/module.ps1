[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"

. (Join-Path $scriptsRoot "common\logging.ps1")
. (Join-Path $repoRoot "modules\packages\manager.ps1")

function Invoke-WindotsModuleAI {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    if (-not $Context.SkipInstall) {
        $mode = if ($Context.Mode) { $Context.Mode } else { "full" }
        Ensure-WindotsModulePackages -Module "ai" -Mode $mode -WhatIf:$Context.WhatIf
    }

    $scriptPath = Join-Path $PSScriptRoot "link-configs.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "[ai] Missing script: $scriptPath"
    }

    if ($Context.WhatIf) {
        Log-Info "[ai] WhatIf: would sync AI config folders."
        return
    }

    Log-Step "[ai] Syncing AI config folders"
    if ($Context.UseSymlinkAI) {
        & $scriptPath -UseSymlink
    }
    else {
        & $scriptPath
    }

    if ($LASTEXITCODE -ne 0) {
        throw "[ai] config sync failed with exit code $LASTEXITCODE"
    }
}
