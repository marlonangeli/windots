[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"

. (Join-Path $scriptsRoot "common\logging.ps1")
. (Join-Path $repoRoot "modules\packages\manager.ps1")

function Invoke-WindotsModuleTerminal {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    if (-not $Context.SkipInstall) {
        $mode = if ($Context.Mode) { $Context.Mode } else { "full" }
        Ensure-WindotsModulePackages -Module "terminal" -Mode $mode -WhatIf:$Context.WhatIf
    }

    $templatePath = Join-Path $repoRoot "home\dot_config\windows-terminal\settings.json.tmpl"
    $hookPath = Join-Path $repoRoot "home\.chezmoiscripts\run_after_40-sync-windows-terminal.ps1.tmpl"

    if (-not (Test-Path $templatePath)) {
        throw "[terminal] Missing template: $templatePath"
    }

    if (-not (Test-Path $hookPath)) {
        throw "[terminal] Missing sync hook: $hookPath"
    }

    Log-Info "[terminal] Windows Terminal template and sync hook are present."
}
