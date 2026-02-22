[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"

. (Join-Path $scriptsRoot "common\logging.ps1")
. (Join-Path $repoRoot "modules\packages\manager.ps1")

function Invoke-WindotsModuleDevelopment {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    if ($Context.SkipInstall) {
        Log-Info "[development] Skipped package installation because -SkipInstall was set."
        return
    }

    $mode = if ($Context.Mode) { $Context.Mode } else { "full" }

    $selectedPackages = @()
    if ($Context.PackageSelections -and $Context.PackageSelections.ContainsKey("development")) {
        $selectedPackages = @($Context.PackageSelections["development"])
    }

    Ensure-WindotsModulePackages -Module "development" -Mode $mode -WhatIf:$Context.WhatIf -PromptForSelection -NoPrompt:$Context.NoPrompt -SelectedPackages $selectedPackages
}
