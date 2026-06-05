[CmdletBinding()]
param([switch]$UseSymlink)

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "modules\ai\link-configs.ps1"

if (-not (Test-Path $scriptPath)) {
    throw "AI sync script not found: $scriptPath"
}

& $scriptPath -UseSymlink:$UseSymlink
