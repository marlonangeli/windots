[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"

. (Join-Path $scriptsRoot "common\logging.ps1")
. (Join-Path $repoRoot "modules\packages\manager.ps1")

function Invoke-WindotsOptionalJiraCliInstall {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{},
        [switch]$InstallJiraCli
    )

    if (-not $InstallJiraCli) {
        Log-PackageStatus -Package "jira-cli" -Status "skipped by choice" -StatusColor Cyan
        return
    }

    $installerPath = Join-Path $PSScriptRoot "install-jira-cli.ps1"
    if (-not (Test-Path $installerPath)) {
        Log-Warn "[secrets] jira-cli installer script missing: $installerPath"
        return
    }

    if ($Context.WhatIf) {
        Log-Output "WhatIf: would install jira-cli from ankitpokhrel/jira-cli releases."
        return
    }

    try {
        & $installerPath
        if (-not $?) {
            throw "jira-cli installer failed"
        }
    }
    catch {
        Log-Warn "[secrets] jira-cli install failed (optional): $($_.Exception.Message)"
    }
}

function Invoke-WindotsModuleSecrets {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    if ($Context.SkipSecretsChecks) {
        Log-Info "[secrets] Skipped because -SkipSecretsChecks was set."
        return
    }

    $installJiraCli = $false
    if (-not $Context.SkipInstall) {
        $installJiraCli = Confirm-WindotsChoice -Message "Install Jira CLI from ankitpokhrel/jira-cli releases?" -NoPrompt:$Context.NoPrompt

        $mode = if ($Context.Mode) { $Context.Mode } else { "full" }
        Ensure-WindotsModulePackages -Module "secrets" -Mode $mode -WhatIf:$Context.WhatIf
        Invoke-WindotsOptionalJiraCliInstall -Context $Context -InstallJiraCli:$installJiraCli
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
        if (-not $?) {
            throw "[secrets] migration checks failed"
        }
    }

    if (Test-Path $depsPath) {
        Log-Step "[secrets] Running dependency checks"
        & $depsPath
        if (-not $?) {
            throw "[secrets] dependency checks failed"
        }
    }
}
