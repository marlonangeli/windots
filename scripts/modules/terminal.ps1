[CmdletBinding()]
param()

$scriptsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptsRoot
. (Join-Path $scriptsRoot "common\logging.ps1")

function Invoke-WindotsModuleTerminal {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    $templatePath = Join-Path $repoRoot "home\dot_config\windows-terminal\settings.json.tmpl"
    $hookPath = Join-Path $repoRoot "home\.chezmoiscripts\run_after_40-sync-windows-terminal.ps1.tmpl"

    if (-not (Test-Path $templatePath)) {
        throw "[terminal] Windows Terminal template missing: $templatePath"
    }

    if (-not (Test-Path $hookPath)) {
        throw "[terminal] Windows Terminal sync hook missing: $hookPath"
    }

    Log-Info "[terminal] Template and sync hook are present."
    Log-Info "[terminal] Sync is handled by chezmoi run_after hook."
}
