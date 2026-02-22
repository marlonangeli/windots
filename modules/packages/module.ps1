[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"

. (Join-Path $scriptsRoot "common\logging.ps1")
. (Join-Path $repoRoot "modules\packages\manager.ps1")

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
    Ensure-WindotsModulePackages -Module "packages" -Mode $mode -WhatIf:$Context.WhatIf -PromptForSelection -NoPrompt:$Context.NoPrompt
}
