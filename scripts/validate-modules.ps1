[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot "common\logging.ps1")
. (Join-Path $repoRoot "modules\module-registry.ps1")

Log-Step "Validating module registry..."

$result = Test-WindotsModuleRegistry -ScriptsRoot $repoRoot
if (-not $result.IsValid) {
    foreach ($err in $result.Errors) {
        Log-Error $err
    }
    exit 1
}

$moduleNames = $result.Modules | Select-Object -ExpandProperty Name
Log-Info ("Module registry OK: " + ($moduleNames -join ", "))
