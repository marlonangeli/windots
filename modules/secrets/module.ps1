[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"

. (Join-Path $scriptsRoot "common\logging.ps1")
. (Join-Path $repoRoot "modules\packages\manager.ps1")

function Invoke-WindotsModuleSecrets {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    if ($Context.SkipSecretsChecks) {
        Log-Info "[secrets] Skipped because -SkipSecretsChecks was set."
        return
    }

    if (-not $Context.SkipInstall) {
        $mode = if ($Context.Mode) { $Context.Mode } else { "full" }
        Ensure-WindotsModulePackages -Module "secrets" -Mode $mode -WhatIf:$Context.WhatIf
    }

    $migratePath = Join-Path $PSScriptRoot "migrate.ps1"
    $depsPath = Join-Path $PSScriptRoot "deps-check.ps1"

    if ($Context.WhatIf) {
        Log-Info "[secrets] WhatIf: would run migration and dependency checks."
        return
    }

    if (Test-Path $migratePath) {
        Log-Step "[secrets] Running migration checks"
        & $migratePath
        if ($LASTEXITCODE -ne 0) {
            throw "[secrets] migration checks failed with exit code $LASTEXITCODE"
        }
    }

    if (Test-Path $depsPath) {
        Log-Step "[secrets] Running dependency checks"
        & $depsPath
        if ($LASTEXITCODE -ne 0) {
            throw "[secrets] dependency checks failed with exit code $LASTEXITCODE"
        }
    }
}
